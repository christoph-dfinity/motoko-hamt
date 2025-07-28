import Array "mo:core/Array";
import Char "mo:core/Char";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Option "mo:core/Option";
import Runtime "mo:core/Runtime";
import Stack "mo:core/Stack";
import Text "mo:core/Text";

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
    root : Bitmapped<A>;
    size : Nat;
  };

  public func new<A>() : Hamt<A> = {
    root = { bitmap = 0; nodes = []; };
    size = 0;
  };

  public func size<A>(hamt : Hamt<A>) : Nat {
    hamt.size;
  };

  public func get<A>(hamt : Hamt<A>, hash : Hash) : ?A {
    let (_, _, #success(_, v)) = getWithAnchor(hamt.root, 0, hash) else return null;
    ?v
  };

  public func add<A>(hamt : Hamt<A>, hash : Hash, value : A) : Hamt<A> {
    insert(hamt, hash, value).0;
  };

  public func insert<A>(hamt : Hamt<A>, hash : Hash, value : A) : (Hamt<A>, ?A) {
    let (newRoot, replaced) = addMapped(hamt.root, 0, hash, value);
    let newSize = if (Option.isSome(replaced)) { hamt.size } else { hamt.size + 1 };
    ({ root = newRoot; size = newSize }, replaced);
  };

  public func addMapped<A>(anchor : Bitmapped<A>, shift : Nat, hash : Hash, value : A) : (Bitmapped<A>, ?A) {
    let pos = bitpos(hash, shift);
    let ix = index(anchor.bitmap, pos);
    if ((anchor.bitmap & pos) == 0) {
      return ({ anchor with
        bitmap = anchor.bitmap | pos;
        nodes = insertArray(anchor.nodes, #leaf((hash, value)), ix)
      }, null)
    };
    switch (anchor.nodes[ix]) {
      case (#leaf(l)) {
        let (newNode : Node<A>, replaced) = if (l.0 == hash) {
          (#leaf(hash, value), ?l.1)
        } else {
          (#bitMapped(mergeLeafs(shift + BITS_PER_LEVEL, l, hash, value)), null)
        };
        ({ anchor with nodes = replaceArray(anchor.nodes, newNode, ix) }, replaced)
      };
      case (#bitMapped(bm)) {
        let (newNode, replaced) = addMapped(bm, shift + BITS_PER_LEVEL, hash, value);
        ({ anchor with nodes = replaceArray(anchor.nodes, #bitMapped(newNode), ix) }, replaced)
      }
    };
  };

  public func remove<A>(hamt : Hamt<A>, hash : Hash) : (Hamt<A>, ?A) {
    switch (removeRec(hamt.root, 0, hash)) {
      case (#notFound) (hamt, null);
      case (#success(l)) ({ root = l.newNode; size = hamt.size - 1 }, ?l.removed.1);
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

  type Node<A> = {
    #bitMapped : Bitmapped<A>;
    #leaf : Leaf<A>;
  };

  type Bitmapped<A> = { bitmap : Bitmap; nodes : [Node<A>] };
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
          (shift, anchor, #success(l));
        } else {
          (shift, anchor, #conflict(l));
        };
      };
      case (#bitMapped(bm)) {
        getWithAnchor(bm, shift + BITS_PER_LEVEL, hash);
      };
    };
  };

  func mergeLeafs<A>(shift : Nat, leaf : Leaf<A>, h2 : Hash, v2 : A) : Bitmapped<A> {
    let nextPos1 = bitpos(leaf.0, shift);
    let nextPos2 = bitpos(h2, shift);
    if (nextPos1 != nextPos2) {
      let bitmap = nextPos1 | nextPos2;
      let nodes : [Node<A>] = if (nextPos1 < nextPos2) {
        [#leaf(leaf), #leaf(h2, v2)]
      } else {
        [#leaf(h2, v2), #leaf(leaf)]
      };
      { bitmap; nodes };
    } else {
      let bitmap = nextPos1;
      let newNode : Bitmapped<A> = mergeLeafs<A>(shift + BITS_PER_LEVEL, leaf, h2, v2);
      { bitmap; nodes = [#bitMapped(newNode)] };
    };
  };

  type RemoveResult<A> = {
    #notFound;
    #success : { newNode : Bitmapped<A>; removed : Leaf<A> };
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
          switch (result) {
            case (#notFound) { return result };
            case (#gathered(g)) {
              if (Nat64.bitcountNonZero(anchor.bitmap) == 1 and shift != 0) {
                return result
              } else {
                let newNode = { anchor with nodes = replaceArray(anchor.nodes, #leaf(g.newNode), ix) };
                return #success({ newNode; removed = g.removed })
              };
            };
            case (#success(s)) {
              let newNode = { anchor with nodes = replaceArray(anchor.nodes, #bitMapped(s.newNode), ix) };
              return #success({ newNode; removed = s.removed })
            };
          };
        };
        case (#leaf(l)) {
          if (hash != l.0) {
            return #notFound
          };
          let rows = Nat64.bitcountNonZero(anchor.bitmap);
          // We never gather the root node
          if (rows == 1 and shift == 0) {
            return #success({ newNode = { bitmap = 0; nodes = [] }; removed = l })
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
            let newBitmap : Bitmap = anchor.bitmap & ^pos;
            return #success({ newNode = { bitmap = newBitmap; nodes = [other] }; removed = l })
          } else {
            let newNodes : [Node<A>] = removeArray(anchor.nodes, ix);
            let newBitmap : Bitmap = anchor.bitmap & ^pos;
            return #success({ newNode = { bitmap = newBitmap; nodes = newNodes }; removed = l })
          };
        };
      };
    };
  };

  // Copied verbatim from imperative module
  type NodeCursor<A> = { node : Anchor<A>; var index : Nat };
  type IterState<A> = {
    var stack : Stack.Stack<NodeCursor<A>>;
  };

  public func iter<A>(hamt : Hamt<A>) : Iter.Iter<(Hash, A)> {
    let state : IterState<A> = { var stack = Stack.singleton({ node = hamt.root; var index = 0 }) };
    object {
      public func next() : ?(Hash, A) {
        label outer loop {
          let ?current = Stack.peek(state.stack) else { return null };
          if (current.node.nodes.size() <= current.index) {
            ignore Stack.pop(state.stack);
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

  // Exposed for testing/debugging
  public func maxDepth<A>(hamt : Hamt<A>) : Nat {
    func depth<A>(node : Node<A>) : Nat {
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

  func insertArray<A>(as : [A], a : A, ix : Nat) : [A] {
    Array.tabulate(
      as.size() + 1,
      func(i : Nat) : A {
        if (i < ix) { as[i] }
        else if (i == ix) { a }
        else { as[i - 1] };
      },
    );
  };

  func replaceArray<A>(as : [A], a : A, ix : Nat) : [A] {
    Array.tabulate(
      as.size(),
      func(i : Nat) : A {
        if (i == ix) { a } else { as[i] };
      },
    );
  };

  func removeArray<A>(as : [A], ix : Nat) : [A] {
    Array.tabulate(
      (as.size() - 1 : Nat),
      func(i : Nat) : A {
        if (i < ix) { as[i] } else { as[i + 1] };
      },
    );
  };
};
