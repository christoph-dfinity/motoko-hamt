import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Runtime "mo:core/Runtime";
import Stack "mo:core/Stack";
import Text "mo:core/Text";
import VarArray "mo:core/VarArray";

import { showBinary } "./Utils";

module {
  public type Hash = Nat64;
  public type Bitmap = Nat64;

  let BITS_PER_LEVEL : Nat64 = 6;
  let SUBKEY_MASK : Nat64 = 63;

  public func toText<A>(self : Hamt<A>, toText : (implicit : A -> Text)) : Text {
    let showNode = func(node : Node<A>) : Text {
      switch (node) {
        case (#leaf(h, v)) {
          "(#leaf " # showBinary(h) # " " # toText(v) # ")";
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
    showNode(#bitMapped(self.root));
  };

  public func showStructure<A>(self : Hamt<A>) : Text {
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
    showNode(#bitMapped(self.root));
  };

  public type Hamt<A> = {
    var root : Bitmapped<A>;
    var size_ : Nat;
  };

  public func new<A>() : Hamt<A> = {
    var root = {
      var bitmap = 0;
      var nodes = [var];
    };
    var size_ = 0;
  };

  public func singleton<A>(hash : Hash, value : A) : Hamt<A> {
    let hamt : Hamt<A> = new();
    ignore hamt.insert(hash, value);
    hamt
  };

  public func fromIter<A>(iter : Iter.Iter<(Hash, A)>) : Hamt<A> {
    let hamt : Hamt<A> = new();
    for ((h, v) in iter) {
      ignore hamt.insert(h, v);
    };
    hamt
  };

  public func clear<A>(self : Hamt<A>) {
    self.root := {
      var bitmap = 0;
      var nodes = [var];
    };
    self.size_ := 0
  };

  public func get<A>(self : Hamt<A>, hash : Hash) : ?A {
    let (_, _, #success(_, v)) = self.root.getWithAnchor(0 : Nat64, hash) else return null;
    ?v
  };

  public func insert<A>(self : Hamt<A>, hash : Hash, value : A) : ?A {
    var previous : ?A = null;
    self.upsert(hash, func (prev) {
      previous := prev;
      value
    });
    previous
  };

  public func upsert<A>(self : Hamt<A>, hash : Hash, update : ?A -> A) {
    let (shift, anchor, result) = self.root.getWithAnchor(0 : Nat64, hash);
    switch (result) {
      case (#success(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        anchor.nodes[ix] := #leaf(hash, update(?prev.1));
      };
      case (#missing) {
        let pos = bitpos(hash, shift);
        anchor.bitmap |= pos;
        let ix = index(anchor.bitmap, pos);
        let newNodes = anchor.nodes.insertVarArray(#leaf((hash, update(null))), ix);
        anchor.nodes := newNodes;
        self.size_ += 1;
      };
      case (#conflict(prev)) {
        let ix = hashIndex(hash, anchor.bitmap, shift);
        let newNode = mergeLeafs<A>(shift +% BITS_PER_LEVEL, prev, hash, update(null));
        anchor.nodes[ix] := #bitMapped(newNode);
        self.size_ += 1;
      };
    }
  };

  public func remove<A>(self : Hamt<A>, hash : Hash) : ?A {
    switch (self.root.removeRec(0 : Nat64, hash)) {
      case (#notFound) null;
      case (#success(l)) {
        self.size_ -= 1;
        ?l.1;
      };
      case (#gathered(_)) Runtime.trap("Must never gather the root node");
    };
  };

  // func mask(hash : Hash, shift : Nat) : Nat64 {
  //   (hash >> Nat64.fromNat(shift)) & SUBKEY_MASK;
  // };

  func bitpos(hash : Hash, shift : Nat64) : Nat64 {
    // Inlined mask
    1 << ((hash >> shift) & SUBKEY_MASK);
  };

  func index(bitmap : Bitmap, pos : Nat64) : Nat {
    Nat64.toNat(Nat64.bitcountNonZero(bitmap & (pos -% 1)));
  };

  // Same as chaining bitpos and index, but saves a few allocations by inlining
  func hashIndex(hash : Hash, bitmap : Bitmap, shift : Nat64) : Nat {
    // Inlined bitpos
    let pos = 1 << ((hash >> shift) & SUBKEY_MASK);
    Nat64.toNat(Nat64.bitcountNonZero(bitmap & (pos -% 1)));
  };

  type Node<A> = {
    #bitMapped : Bitmapped<A>;
    #leaf : Leaf<A>;
  };

  type Bitmapped<A> = { var bitmap : Bitmap; var nodes : [var Node<A>] };

  type Leaf<A> = (Hash, A);

  type Anchor<A> = Bitmapped<A>;

  type GetResult<A> = (
    shift : Nat64,
    anchor : Anchor<A>,
    result : { #success : Leaf<A>; #conflict : Leaf<A>; #missing },
  );

  func getWithAnchor<A>(self : Anchor<A>, shift : Nat64, hash : Hash) : GetResult<A> {
    let pos = bitpos(hash, shift);
    if ((self.bitmap & pos) == 0) {
      return (shift, self, #missing);
    };
    let ix = index(self.bitmap, pos);
    switch (self.nodes[ix]) {
      case (#leaf(l)) {
        if (l.0 == hash) {
          (shift, self, #success(l)) ;
        } else {
          (shift, self, #conflict(l));
        };
      };
      case (#bitMapped(bm)) {
        bm.getWithAnchor(shift +% BITS_PER_LEVEL, hash);
      }
    };
  };

  func mergeLeafs<A>(shift : Nat64, leaf : Leaf<A>, h2 : Hash, v2 : A) : Bitmapped<A> {
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
      let newNode : Bitmapped<A> = mergeLeafs<A>(shift +% BITS_PER_LEVEL, leaf, h2, v2);
      { var bitmap; var nodes = [var #bitMapped(newNode)] };
    };
  };

  type RemoveResult<A> = {
    #notFound;
    #success : Leaf<A>;
    #gathered : { newNode : Leaf<A>; removed : Leaf<A> };
  };

  func removeRec<A>(self : Anchor<A>, shift : Nat64, hash : Hash) : RemoveResult<A> {
    let pos = bitpos(hash, shift);
    if ((pos & self.bitmap) == 0) {
      #notFound;
    } else {
      let ix = index(self.bitmap, pos);
      switch (self.nodes[ix]) {
        case (#bitMapped(n)) {
          let result = n.removeRec(shift +% BITS_PER_LEVEL, hash);
          let #gathered(g) = result else return result;
          if (Nat64.bitcountNonZero(self.bitmap) == 1 and shift != 0) {
            return result
          } else {
            self.nodes[ix] := #leaf(g.newNode);
            #success(g.removed)
          }
        };
        case (#leaf(l)) {
          if (hash != l.0) {
            return #notFound
          };
          let rows = Nat64.bitcountNonZero(self.bitmap);
          // We never gather the root node
          if (rows == 1 and shift == 0) {
            self.bitmap := 0;
            self.nodes := [var];
            return #success(l)
          };
          if (rows == 2) {
            let other = if (ix == 1) { self.nodes[0] } else { self.nodes[1] };
            switch (other) {
              case (#leaf(other)) {
                // We never gather the root node
                if (shift != 0) {
                  return #gathered { newNode = other; removed = l }
                }
              };
              case (_) {};
            };
            self.bitmap &= ^pos;
            self.nodes := [var other];
            return #success(l)
          } else {
            let newNodes : [var Node<A>] = self.nodes.removeVarArray(ix);
            self.bitmap &= ^pos;
            self.nodes := newNodes;
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
  public func entries<A>(self : Hamt<A>) : Iter.Iter<(Hash, A)> {
    let state : IterState<A> = { var stack = Stack.singleton({ node = self.root; var index = 0 }) };
    object {
      public func next() : ?(Hash, A) {
        loop {
          let ?current = state.stack.peek() else { return null };
          if (current.node.nodes.size() <= current.index) {
            ignore state.stack.pop();
            continue;
          };
          switch (current.node.nodes[current.index]) {
            case (#leaf(l)) {
              current.index += 1;
              return ?l
            };
            case (#bitMapped(bm)) {
              current.index += 1;
              state.stack.push({ node = bm; var index = 0 });
              continue;
            }
          };
        };
        null
      }
    };
  };

  public func equal<A>(self : Hamt<A>, other : Hamt<A>, equal : (implicit : (A, A) -> Bool)) : Bool {
    if (self.size_ != other.size_) { return false };
    self.root.equalRec(other.root, equal)
  };

  func equalRec<A>(self : Bitmapped<A>, other : Bitmapped<A>, equal : (A, A) -> Bool) : Bool {
    // We can use this fast structural equality check, because we canonicalize on deletion
    if (self.bitmap != other.bitmap) { return false };
    var i : Nat = 0;
    let size : Nat = self.nodes.size();
    while (i < size) {
      switch (self.nodes[i], other.nodes[i]) {
        case (#leaf(lh, lv), #leaf(rh, rv)) {
          if (lh != rh or not equal(lv, rv)) {
            return false
          };
        };
        case (#bitMapped(l), #bitMapped(r)) {
          if (not l.equalRec(r, equal)) {
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
  public func maxDepth<A>(self : Hamt<A>) : Nat {
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
    depth(#bitMapped(self.root))
  };

  func insertVarArray<A>(self : [var A], a : A, ix : Nat) : [var A] {
    VarArray.tabulate(
      self.size() + 1,
      func(i : Nat) : A {
        if (i < ix) { self[i] }
        else if (i == ix) { a }
        else { self[i - 1] };
      },
    );
  };

  func removeVarArray<A>(self : [var A], ix : Nat) : [var A] {
    VarArray.tabulate(
      (self.size() - 1 : Nat),
      func(i : Nat) : A {
        if (i < ix) { self[i] } else { self[i + 1] };
      },
    );
  };
};
