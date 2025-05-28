import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Debug "mo:base/Debug";

module {
  public type Hash = Nat64;
  public type Bitmap = Nat64;

  let BITS_PER_LEVEL = 6;
  let SUBKEY_MASK : Nat64 = 63;

  public func showBinary(x : Hash) : Text {
    var n = x;
    var res = "";
    for (i in Iter.range(0, 63)) {
      if (i != 0 and i % BITS_PER_LEVEL == 0) res := "_" # res;
      if (n & 1 == 1) { res := "1" # res } else { res := "0" # res };
      n := n >> 1;
    };
    res;
  };

  public func showHex(x : Hash) : Text {
    var n = x;
    var res = "";
    for (i in Iter.range(0, 7)) {
      let digit = n & 15;
      if (digit < 10) {
        res := Nat64.toText(digit) # res;
      } else {
        res := Text.fromChar(Char.fromNat32(Nat32.fromNat64(digit + 87))) # res;
      };
      n := n >> 4;
    };
    res;
  };

  public func show<A>(showA : A -> Text, hamt : Hamt<A>) : Text {
    let showNode = func(node : Node<A>) : Text {
      switch (node) {
        case (#leaf(h, v)) {
          "(#leaf " # showBinary(h) # " " # showA(v) # ")";
        };
        case (#bitMapped n) {
          var res = "";
          for (node in n.nodes.values()) {
            res := res # showNode(node) # " ";
          };
          res := Text.trimEnd(res, #text " ");
          "(#mapped " # showBinary(n.bitmap) # " " # res # ")";
        };
      };
    };
    showNode(#bitMapped(hamt.root));
  };

  public func showStructure<A>(hamt : Hamt<A>) : Text {
    let showNode = func(node : Node<A>) : Text {
      switch (node) {
        case (#leaf(h, _)) {
          "(#leaf " # showBinary(h) #")";
        };
        case (#bitMapped n) {
          var res = "";
          for (node in n.nodes.values()) {
            res := res # showNode(node) # " ";
          };
          res := Text.trimEnd(res, #text " ");
          "(#mapped " # showBinary(n.bitmap) # " " # res # ")";
        };
      };
    };
    showNode(#bitMapped(hamt.root));
  };

  public type Hamt<A> = {
    var root : Bitmapped<A>;
  };

  public func new<A>() : Hamt<A> = { var root = {
    var bitmap = 0;
    var nodes = [var];
  }};

  public func get<A>(hamt : Hamt<A>, hash : Hash) : ?A {
    let (_, _, #success(_, v)) = getWithAnchor(hamt.root, 0, hash) else return null;
    ?v
  };

  public func add<A>(hamt : Hamt<A>, hash : Hash, value : A) : ?A {
    let (shift, anchor, result) = getWithAnchor(hamt.root, 0, hash);
    switch (result) {
      case (#success(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        anchor.nodes[ix] := #leaf(hash, value);
        ?prev.1;
      };
      case (#missing) {
        let pos = bitpos(hash, shift);
        anchor.bitmap |= pos;
        let ix = index(anchor.bitmap, pos);
        let newNodes = insertVarArray(anchor.nodes, #leaf((hash, value)), ix);
        anchor.nodes := newNodes;
        null;
      };
      case (#conflict(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        let newNode = mergeLeafs<A>(shift + BITS_PER_LEVEL, prev, hash, value);
        anchor.nodes[ix] := #bitMapped(newNode);
        null;
      };
    };
  };

  public func remove<A>(hamt : Hamt<A>, hash : Hash) : ?A {
    switch (removeRec(hamt.root, 0, hash)) {
      case (#notFound) null;
      case (#success(l)) ?l.1;
      case (#gathered(_)) Debug.trap("Must never gather the root node");
    };
  };

  // func mask(hash : Hash, shift : Nat) : Nat64 {
  //   (hash >> Nat64.fromNat(shift)) & SUBKEY_MASK;
  // };

  func bitpos(hash : Hash, shift : Nat) : Nat64 {
    // Inlined mask
    1 << ((hash >> Nat64.fromNat(shift)) & SUBKEY_MASK);
  };

  func index(bitmap : Bitmap, pos : Nat64) : Nat {
    Nat64.toNat(Nat64.bitcountNonZero(bitmap & (pos - 1)));
  };

  // Same as chaining bitpos and index, but saves a few allocations by inlining
  func hashIndex(hash : Hash, bitmap : Bitmap, shift : Nat) : Nat {
    // Inlined bitpos
    let pos = 1 << ((hash >> Nat64.fromNat(shift)) & SUBKEY_MASK);
    Nat64.toNat(Nat64.bitcountNonZero(bitmap & (pos - 1)));
  };

  type Node<A> = {
    #bitMapped : Bitmapped<A>;
    #leaf : Leaf<A>;
  };

  type Bitmapped<A> = { var bitmap : Bitmap; var nodes : [var Node<A>] };
  type Leaf<A> = (Hash, A);

  type Anchor<A> = Bitmapped<A>;

  type GetResult<A> = (
    shift : Nat,
    anchor : Anchor<A>,
    result : { #success : Leaf<A>; #conflict : Leaf<A>; #missing },
  );

  func getWithAnchor<A>(anchor : Anchor<A>, shift : Nat, hash : Hash) : GetResult<A> {
    let pos = bitpos(hash, shift);
    if ((anchor.bitmap & pos) == 0) {
      return (shift, anchor, #missing);
    };
    let ix = index(anchor.bitmap, pos);
    switch (anchor.nodes[ix]) {
      case (#leaf(l)) {
        if (l.0 == hash) {
          (shift, anchor, #success(l)) ;
        } else {
          (shift, anchor, #conflict(l));
        };
      };
      case (#bitMapped(bm)) {
        getWithAnchor(bm, shift + BITS_PER_LEVEL, hash);
      }
    };
  };

  func mergeLeafs<A>(shift : Nat, leaf : Leaf<A>, h2 : Hash, v2 : A) : Bitmapped<A> {
    let nextPos1 = bitpos(leaf.0, shift);
    let nextPos2 = bitpos(h2, shift);
    if (nextPos1 != nextPos2) {
      let bitmap = nextPos1 | nextPos2;
      let nodes : [var Node<A>] = if (nextPos1 < nextPos2) {
        [var #leaf(leaf), #leaf(h2, v2)]
      } else {
        [var #leaf(h2, v2), #leaf(leaf)]
      };
      { var bitmap; var nodes };
    } else {
      let bitmap = nextPos1;
      let newNode : Bitmapped<A> = mergeLeafs<A>(shift + BITS_PER_LEVEL, leaf, h2, v2);
      { var bitmap; var nodes = [var #bitMapped(newNode)] };
    };
  };

  type RemoveResult<A> = {
    #notFound;
    #success : Leaf<A>;
    #gathered : { newNode : Leaf<A>; removed : Leaf<A> };
  };

  func removeRec<A>(anchor : Anchor<A>, shift : Nat, hash : Hash) : RemoveResult<A> {
    let pos = bitpos(hash, shift);
    if ((pos & anchor.bitmap) == 0) {
      return #notFound;
    } else {
      let ix = index(anchor.bitmap, pos);
      switch (anchor.nodes[ix]) {
        case (#bitMapped(n)) {
          let result = removeRec(n, shift + BITS_PER_LEVEL, hash);
          let #gathered(g) = result else return result;
          if (Nat64.bitcountNonZero(anchor.bitmap) == 1 and shift != 0) {
            return result
          } else {
            anchor.nodes[ix] := #leaf(g.newNode);
            #success(g.removed)
          }
        };
        case (#leaf(l)) {
          if (hash != l.0) {
            return #notFound
          };
          let rows = Nat64.bitcountNonZero(anchor.bitmap);
          // We never gather the root node
          if (rows == 1 and shift == 0) {
            anchor.bitmap := 0;
            anchor.nodes := [var];
            return #success(l)
          };
          if (rows == 2) {
            let other = if (ix == 1) { anchor.nodes[0] } else { anchor.nodes[1] };
            switch (other) {
              case (#leaf(other)) {
                // We never gather the root node
                if (shift != 0) {
                  return #gathered { newNode = other; removed = l }
                }
              };
              case (_) {};
            };
            anchor.bitmap &= ^pos;
            anchor.nodes := [var other];
            return #success(l)
          } else {
            let newNodes : [var Node<A>] = removeVarArray(anchor.nodes, ix);
            anchor.bitmap &= ^pos;
            anchor.nodes := newNodes;
            return #success(l)
          };
        };
      };
    };
  };

  // Exposed for testing/debugging
  public func maxDepth<A>(hamt : Hamt<A>) : Nat {
    let depth = func<A>(node : Node<A>) : Nat {
      switch node {
        case (#leaf(_)) 0;
        case (#bitMapped(n)) {
          var d = 0;
          for (child in n.nodes.values()) {
            d := Nat.max(d, depth(child));
          };
          d + 1
        };
      }
    };
    depth(#bitMapped(hamt.root))
  };

  func insertVarArray<A>(as : [var A], a : A, ix : Nat) : [var A] {
    Array.tabulateVar(
      as.size() + 1,
      func(i : Nat) : A {
        if (i < ix) { as[i] }
        else if (i == ix) { a }
        else { as[i - 1] };
      },
    );
  };

  func removeVarArray<A>(as : [var A], ix : Nat) : [var A] {
    Array.tabulateVar(
      (as.size() - 1 : Nat),
      func(i : Nat) : A {
        if (i < ix) { as[i] } else { as[i + 1] };
      },
    );
  };
};
