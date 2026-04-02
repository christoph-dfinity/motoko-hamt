/// Functional Key-Value HashMaps

import Array "mo:core/Array";
import Hamt "Hamt";
import Iter "mo:core/Iter";
import Option "mo:core/Option";
import { type Seed } "../Types";

module {
  /// An immutable persistent key-value hash map.
  /// The map data structure type is stable and can be used for orthogonal persistence.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   // creation
  ///   let seed : HashMap.Seed = (0, 0);
  ///   var map = HashMap.new<Nat, Text>(seed);
  ///   // insertion
  ///   map := HashMap.add(map, HashMap.nat, 0, "Zero");
  ///   // retrieval
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == null;
  ///   // removal
  ///   map := HashMap.delete(map, HashMap.nat, 0);
  ///   assert HashMap.isEmpty(map);
  /// }
  /// ```
  ///
  /// The internal implementation is a [Hash Array Mapped Trie] with 64bit hash keys and
  /// arrays in the leafs. The main advantage over a traditional hashtable is that
  /// the performance of insertion/removal is not amortized, as there's no need for
  /// resizing/rehashing, meaning we avoid the risk of hitting the instruction
  /// limit for very large maps.
  ///
  /// The provided hashing functions (Sip13) are HashDoS resistant as long as the map is
  /// seeded with secure randomness.
  /// [Hash Array Mapped Trie]: https://lampwww.epfl.ch/papers/idealhashtrees.pdf
  public type HashMap<K, V> = {
    hamt : Hamt.Hamt<Bucket.T<K, V>>;
    size_ : Nat;
    seed : Seed;
  };

  /// The empty HashMap.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   var map = HashMap.empty<Nat, Text>(seed);
  ///   assert HashMap.size(map) == 0;
  /// }
  /// ```
  public func empty<K, V>(seed : Seed) : HashMap<K, V> {
    { hamt = Hamt.new(); size_ = 0; seed };
  };

  /// Create a new HashMap with a single entry.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  /// import Iter "mo:core/Iter";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   var map = HashMap.singleton<Nat, Text>(seed, HashMap.nat, 0, "Zero");
  ///   assert Iter.toArray(HashMap.entries(map)) == [(0, "Zero")];
  /// }
  /// ```
  public func singleton<K, V>(
    seed : Seed,
    key : K,
    value : V,
    hash : (implicit : (Seed, K) -> Nat64),
  ) : HashMap<K, V> {
    let hashed = hash(seed, key);
    { hamt = Hamt.singleton(hashed, [(key, value)]); size_ = 1; seed };
  };

  /// Create a HashMap with the entries obtained from an iterator.
  /// If the iterator produces any pairs with equal keys, only one of the corresponding values will be inserted.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  /// import Iter "mo:core/Iter";
  ///
  /// persistent actor {
  ///   transient let iter =
  ///     Iter.fromArray([(0, "Zero"), (2, "Two"), (1, "One")]);
  ///
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(iter, seed, HashMap.nat);
  ///
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///   assert HashMap.get(map, HashMap.nat, 2) == ?"Two";
  /// }
  /// ```
  public func fromIter<K, V>(
    seed : Seed,
    iter : Iter.Iter<(K, V)>,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : HashMap<K, V> {
    // TODO: build mutably and then freeze
    var map : HashMap<K, V> = empty(seed);
    for ((k, v) in iter) {
      map := map.add(k, v);
    };
    map
  };

  /// Given `map` hashed with `hashFn`, insert a new mapping from `key` to `value`.
  ///
  /// If the map did not have this key present, the previous map and null is returned.
  /// If the map did have this key present, a map with the inserted mapping, and the old value is returned.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.empty<Nat, Text>(seed);
  ///   let (map1, v1) = HashMap.insert(map, HashMap.nat, 0, "Zero");
  ///   assert v1 == null;
  ///
  ///   let (map2, v2) = HashMap.insert(map, HashMap.nat, 1, "One");
  ///   assert v2 == null;
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///
  ///   let (map3, v3) = HashMap.insert(map, HashMap.nat, 0, "Nil");
  ///   assert v3 == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Nil";
  /// }
  /// ```
  public func insert<K, V>(
    self : HashMap<K, V>,
    key : K,
    value : V,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : (HashMap<K, V>, ?V) {
    let hashed = hash(self.seed, key);
    var previous : ?V = null;
    let (newMap, _) = self.hamt.upsert(hashed, func (prev) {
      switch (prev) {
        case null [(key, value)];
        case (?bucket) {
          let (newBucket, replaced) = bucket.add(equal, key, value);
          previous := replaced;
          newBucket
        };
      }
    });
    let size_ = if (previous.isNull()) {
      self.size_ + 1;
    } else {
      self.size_
    };
    ({ hamt = newMap; size_; seed = self.seed }, previous)
  };

  /// Adds/replaces the value associated with `key` with `value`
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   var map = HashMap.empty<Nat, Text>(seed);
  ///   map := HashMap.add(map, HashMap.nat, 0, "Zero");
  ///   map := HashMap.add(map, HashMap.nat, 1, "One");
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///
  ///   map := HashMap.add(map, HashMap.nat, 0, "Nil");
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Nil";
  /// }
  /// ```
  public func add<K, V>(
    self : HashMap<K, V>,
    key : K,
    value : V,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : HashMap<K, V> {
    self.insert(key, value).0
  };

  /// Get the value associated with key in the given map if present and `null` otherwise.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (1, "One"), (2, "Two")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///   assert HashMap.get(map, HashMap.nat, 3) == null;
  /// }
  /// ```
  public func get<K, V>(
    self : HashMap<K, V>,
    key : K,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : ?V {
    let hashed = hash(self.seed, key);
    let ?bucket = self.hamt.get(hashed) else return null;
    Bucket.get(bucket, equal, key)
  };

  /// Removes an entry by its key in the map.
  /// No effect if the key is not present.
  ///
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  /// import Iter "mo:core/Iter";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   let (map1, removed1) HashMap.remove(map, HashMap.nat, 1);
  ///   assert removed1 == ?"One";
  ///   assert HashMap.get(map1, HashMap.nat, 1) = null;
  ///   assert HashMap.size(map1) == 2;
  ///   let (map2, removed2) = HashMap.remove(map1, HashMap.nat, 42);
  ///   assert removed2 == null;
  ///   assert HashMap.size(map2) == 2;
  /// }
  /// ```
  public func remove<K, V>(
    self : HashMap<K, V>,
    key : K,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : (HashMap<K, V>, ?V) {
    let hashed = hash(self.seed, key);
    let (newHamt, ?bucket) = Hamt.remove(self.hamt, hashed) else { return (self, null) };
    switch (Bucket.remove(bucket, equal, key)) {
      case null { (self, null) };
      case (?(newBucket, removed)) {
        if (newBucket.size() == 0) {
          ({ hamt = newHamt; size_ = self.size_ - 1; seed = self.seed }, ?removed)
        } else {
          let (newHamt, _) = Hamt.insert(self.hamt, hashed, newBucket);
          ({ hamt = newHamt; size_ = self.size_ - 1; seed = self.seed }, ?removed)
        }
      }
    };
  };

  public func delete<K, V>(
    self : HashMap<K, V>,
    key : K,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : HashMap<K, V> {
    self.remove(key).0
  };

  /// Tests whether the map contains the provided key.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   assert HashMap.containsKey(map, HashMap.nat, 1);
  ///   assert not Map.containsKey(map, HashMap.nat, 3);
  /// }
  /// ```
  public func containsKey<K, V>(
    self : HashMap<K, V>,
    key : K,
    hash : (implicit : (Seed, K) -> Nat64),
    equal : (implicit : (K, K) -> Bool),
  ) : Bool {
    self.get(key).isSome()
  };

  /// Returns an iterator over the key-value pairs in the map,
  /// traversing the entries in arbitary order.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  /// import Nat "mo:core/Nat";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   for ((key, value) in HashMap.entries(map)) {
  ///     Debug.print(Nat.toText(key) # " => " # value);
  ///   }
  /// }
  /// ```
  public func entries<K, V>(self : HashMap<K, V>) : Iter.Iter<(K, V)> {
    let inner = Hamt.entries(self.hamt);
    let ?(_, initialBucket) = inner.next() else {
      return Iter.empty()
    };
    var currentBucket : Iter.Iter<(K, V)> = initialBucket.values();
    object {
      public func next() : ?(K, V) {
        let nextEntry = currentBucket.next();
        switch (nextEntry) {
          case null {
            let ?(_, nextBucket) = inner.next() else { return null };
            currentBucket := nextBucket.values();
            currentBucket.next();
          };
          case _ {
            nextEntry
          };
        };
      };
    };
  };

  /// Returns an iterator over the keys in the map, traversing the entries in arbitary order.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  /// import Nat "mo:core/Nat";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   for (key in HashMap.keys(map)) {
  ///     Debug.print(Nat.toText(key));
  ///   }
  /// }
  /// ```
  public func keys<K, V>(self : HashMap<K, V>) : Iter.Iter<K> {
    self.entries().map(func (k, _) = k);
  };

  /// Returns an iterator over the values in the map, traversing the entries in arbitary order.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///     seed, HashMap.nat,
  ///   );
  ///
  ///   for (value in HashMap.values(map)) {
  ///     Debug.print(value);
  ///   }
  /// }
  /// ```
  public func values<K, V>(self : HashMap<K, V>) : Iter.Iter<V> {
    self.entries().map(func (_, v) = v);
  };

  /// Determines whether a key-value map is empty.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.new<Nat, Text>(seed);
  ///   assert HashMap.isEmpty(map);
  ///   ignore HashMap.insert(map, HashMap.nat, 0, "Hello");
  ///   assert not HashMap.isEmpty(map);
  /// }
  /// ```
  public func isEmpty<K, V>(self : HashMap<K, V>) : Bool {
    self.size_ == 0
  };

  /// Return the number of entries in a key-value map.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/pure/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.new<Nat, Text>(seed);
  ///   assert HashMap.size(map) == 0;
  ///   ignore HashMap.insert(map, HashMap.nat, 0, "Zero")
  ///   assert HashMap.size(map) == 1;
  /// }
  /// ```
  public func size<K, V>(self : HashMap<K, V>) : Nat {
    self.size_
  };

  public func equal<K, V>(
    self : HashMap<K, V>,
    other : HashMap<K, V>,
    equalK : (implicit : (equal : (K, K) -> Bool)),
    equalV : (implicit : (equal : (V, V) -> Bool)),
  ) : Bool {
    self.hamt.equal(other.hamt, func(l, r) { Bucket.equal(l, r, equalK, equalV) })
  };

  module Bucket {
    public type T<K, V> = [(K, V)];

    public func add<K, V>(self : T<K, V>, eq : (K, K) -> Bool, key : K, value : V) : (T<K, V>, ?V) {
      var i : Nat = 0;
      let size = self.size();
      while (i < size) {
        let (k, v) = self[i];
        if (eq(k, key)) {
          let newBucket = Array.tabulate<(K, V)>(size, func j = if (i != j) self[j] else (key, value));
          return (newBucket, ?v)
        };
        i += 1;
      };
      let newBucket = Array.tabulate<(K, V)>(size + 1, func i = if (i != size) self[i] else (key, value));
      (newBucket, null)
    };

    public func get<K, V>(self : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      var i : Nat = 0;
      let size = self.size();
      while (i < size) {
        let (k, v) = self[i];
        if (eq(k, key)) {
          return ?v;
        };
        i += 1;
      };
      null;
    };

    public func remove<K, V>(self : T<K, V>, eq : (K, K) -> Bool, key : K) : ?(T<K, V>, V) {
      var i : Nat = 0;
      let size = self.size();
      while (i < size) {
        let (k, v) = self[i];
        if (eq(k, key)) {
          let newBucket = Array.tabulate<(K, V)>(size - 1, func ix = if (ix < i) self[ix] else self[ix + 1]);
          return ?(newBucket, v);
        };
        i += 1;
      };
      null;
    };

    public func equal<K, V>(self : T<K, V>, other : T<K, V>, eqK : (K, K) -> Bool, eqV : (V, V) -> Bool) : Bool {
      if (self.size() != other.size()) {
        return false
      };
      label outer for ((ks, vs) in self.vals()) {
        for ((ko, vo) in other.vals()) {
          if (eqK(ks, ko) and eqV(vs, vo)) {
            continue outer;
          };
        };
        return false
      };
      true;
    };
  };
}
