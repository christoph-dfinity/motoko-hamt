import Char "mo:core/Char";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Runtime "mo:core/Runtime";
import Stack "mo:core/Stack";
import Text "mo:core/Text";

// TODO: Swap around once https://github.com/dfinity/motoko-core/pull/334 lands
// import VarArray "mo:core/VarArray";
import Prim "mo:prim";

module {
  public type Hash = Nat64;
  public type Bitmap = Nat64;

  let BITS_PER_LEVEL = 6;
  let SUBKEY_MASK : Nat64 = 63;

  public func showBinary(x : Hash) : Text {
    var n = x;
    var res = "";
    for (i in Nat.range(0, 64)) {
      if (i != 0 and i % BITS_PER_LEVEL == 0) res := "_" # res;
      if (n & 1 == 1) { res := "1" # res } else { res := "0" # res };
      n := n >> 1;
    };
    res;
  };

  public func showHex(x : Hash) : Text {
    var n = x;
    var res = "";
    for (i in Nat.range(0, 8)) {
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
    var size : Nat;
  };

  public func new<A>() : Hamt<A> = {
    var root = {
      var bitmap = 0;
      var nodes = [var];
    };
    var size = 0;
  };

  public func singleton<A>(hash : Hash, value : A) : Hamt<A> {
    let hamt : Hamt<A> = new();
    ignore insert(hamt, hash, value);
    hamt
  };

  public func fromIter<A>(iter : Iter.Iter<(Hash, A)>) : Hamt<A> {
    let hamt : Hamt<A> = new();
    for ((h, v) in iter) {
      ignore insert(hamt, h, v);
    };
    hamt
  };

  public func clear<A>(hamt : Hamt<A>) {
    hamt.root := {
      var bitmap = 0;
      var nodes = [var];
    };
    hamt.size := 0
  };

  public func get<A>(hamt : Hamt<A>, hash : Hash) : ?A {
    let (_, _, #success(_, v)) = getWithAnchor(hamt.root, 0, hash) else return null;
    ?v
  };

  public func insert<A>(hamt : Hamt<A>, hash : Hash, value : A) : ?A {
    var previous : ?A = null;
    upsert(hamt, hash, func (prev : ?A) : A {
      previous := prev;
      value
    });
    previous
  };

  public func upsert<A>(hamt : Hamt<A>, hash : Hash, update : ?A -> A) {
    let (shift, anchor, result) = getWithAnchor(hamt.root, 0, hash);
    switch (result) {
      case (#success(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        anchor.nodes[ix] := #leaf(hash, update(?prev.1));
      };
      case (#missing) {
        let pos = bitpos(hash, shift);
        anchor.bitmap |= pos;
        let ix = index(anchor.bitmap, pos);
        let newNodes = insertVarArray(anchor.nodes, #leaf((hash, update(null))), ix);
        anchor.nodes := newNodes;
        hamt.size += 1;
      };
      case (#conflict(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        let newNode = mergeLeafs<A>(shift + BITS_PER_LEVEL, prev, hash, update(null));
        anchor.nodes[ix] := #bitMapped(newNode);
        hamt.size += 1;
      };
    }
  };

  public func remove<A>(hamt : Hamt<A>, hash : Hash) : ?A {
    switch (removeRec(hamt.root, 0, hash)) {
      case (#notFound) null;
      case (#success(l)) {
        hamt.size -= 1;
        ?l.1;
      };
      case (#gathered(_)) Runtime.trap("Must never gather the root node");
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

  type NodeCursor<A> = { node : Anchor<A>; var index : Nat };
  type IterState<A> = {
    var stack : Stack.Stack<NodeCursor<A>>;
  };

  // The underlying Hamt must not by modified while iterating
  public func entries<A>(hamt : Hamt<A>) : Iter.Iter<(Hash, A)> {
    let state : IterState<A> = { var stack = Stack.singleton({ node = hamt.root; var index = 0 }) };
    object {
      public func next() : ?(Hash, A) {
        label outer loop {
          let ?current = Stack.pop(state.stack) else { return null };
          if (current.node.nodes.size() <= current.index) {
            continue outer;
          };
          switch (current.node.nodes[current.index]) {
            case (#leaf(l)) {
              current.index += 1;
              return ?l
            };
            case (#bitMapped(bm)) {
              current.index += 1;
              Stack.push(state.stack, { node = bm; var index = 0 });
              continue outer;
            }
          };
        };
        null
      }
    };
  };

  public func equals<A>(left : Hamt<A>, right : Hamt<A>, equals : (A, A) -> Bool) : Bool {
    if (left.size != right.size) { return false };
    equalsRec(left.root, right.root, equals)
  };

  func equalsRec<A>(left : Bitmapped<A>, right : Bitmapped<A>, equals : (A, A) -> Bool) : Bool {
    if (left.bitmap != right.bitmap) { return false };
    var i : Nat = 0;
    let size : Nat = left.nodes.size();
    while (i < size) {
      switch (left.nodes[i], right.nodes[i]) {
        case (#leaf(lh, lv), #leaf(rh, rv)) {
          if (lh != rh or not equals(lv, rv)) {
            return false
          };
        };
        case (#bitMapped(l), #bitMapped(r)) {
          if (not equalsRec(l, r, equals)) {
            return false
          }
        };
        case _ {
          return false
        };
      };
      i += 1;
    };
    true
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
    Prim.Array_tabulateVar(
      as.size() + 1,
      func(i : Nat) : A {
        if (i < ix) { as[i] }
        else if (i == ix) { a }
        else { as[i - 1] };
      },
    );
  };

  func removeVarArray<A>(as : [var A], ix : Nat) : [var A] {
    Prim.Array_tabulateVar(
      (as.size() - 1 : Nat),
      func(i : Nat) : A {
        if (i < ix) { as[i] } else { as[i + 1] };
      },
    );
  };
};
