/// Functional Key-Value HashMaps

// TODO: Implement equals

import Array "mo:core/Array";
import Blob "mo:core/Blob";
import Hamt "Hamt";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Option "mo:core/Option";
import Principal "mo:core/Principal";
import Sip13 "mo:siphash/Sip13";
import Text "mo:core/Text";

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
    size : Nat;
    seed : Seed;
  };

  /// The provided hashing functions will use this seed to produce HashDoS resistant hashes.
  /// Needs to be sourced from secure randomness
  public type Seed = (Nat64, Nat64);

  /// Holds both a hash and equality function for the HashMap's key type
  public type HashFn<K> = (
    hash : (Seed, K) -> Nat64,
    eq : (K, K) -> Bool
  );

  /// A hashing function for Blob
  public let blob : HashFn<Blob> = (Sip13.hashBlob, Blob.equal);

  /// A hashing function for Text
  public let text : HashFn<Text> = (Sip13.hashText, Text.equal);

  /// A hashing function for Nat
  public let nat : HashFn<Nat> = (Sip13.hashNat, Nat.equal);

  /// A hashing function for Int
  public let int : HashFn<Int> = (Sip13.hashInt, Int.equal);

  /// A hashing function for Principals
  public let principal : HashFn<Principal> =
    (func (s, p) = Sip13.hashBlob(s, Principal.toBlob(p)), Principal.equal);

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
    { hamt = Hamt.new(); size = 0; seed };
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
  public func singleton<K, V>(seed : Seed, hashFn : HashFn<K>, key : K, value : V) : HashMap<K, V> {
    let hashed = hashFn.0(seed, key);
    { hamt = Hamt.singleton(hashed, [(key, value)]); size = 1; seed };
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
  ///   let map = HashMap.fromIter<Nat, Text>(seed, HashMap.nat, iter);
  ///
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///   assert HashMap.get(map, HashMap.nat, 2) == ?"Two";
  /// }
  /// ```
  public func fromIter<K, V>(seed : Seed, hashFn : HashFn<K>, iter : Iter.Iter<(K, V)>) : HashMap<K, V> {
    // TODO: build mutably and then freeze
    var map : HashMap<K, V> = empty(seed);
    for ((k, v) in iter) {
      map := add(map, hashFn, k, v);
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
  public func insert<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K, value : V) : (HashMap<K, V>, ?V) {
    let hashed = hashFn.0(map.seed, key);
    var previous : ?V = null;
    let (newMap, _) = Hamt.upsert(map.hamt, hashed, func (prev : ?Bucket.T<K, V>) : Bucket.T<K, V> {
      switch (prev) {
        case null [(key, value)];
        case (?bucket) {
          let (newBucket, replaced) = Bucket.add(bucket, hashFn.1, key, value);
          previous := replaced;
          newBucket
        };
      }
    });
    let size = if (Option.isNull(previous)) {
      map.size + 1;
    } else {
      map.size
    };
    ({ hamt = newMap; size; seed = map.seed }, previous)
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
  public func add<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K, value : V) : HashMap<K, V> {
    insert(map, hashFn, key, value).0
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (1, "One"), (2, "Two")].values()
  ///   );
  ///
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///   assert HashMap.get(map, HashMap.nat, 3) == null;
  /// }
  /// ```
  public func get<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K) : ?V {
    let hashed = hashFn.0(map.seed, key);
    let ?bucket = Hamt.get(map.hamt, hashed) else return null;
    Bucket.get(bucket, hashFn.1, key)
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
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
  public func remove<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K) : (HashMap<K, V>, ?V) {
    let hashed = hashFn.0(map.seed, key);
    let (newHamt, ?bucket) = Hamt.remove(map.hamt, hashed) else { return (map, null) };
    switch (Bucket.remove(bucket, hashFn.1, key)) {
      case null { (map, null) };
      case (?(newBucket, removed)) {
        if (newBucket.size() == 0) {
          ({ hamt = newHamt; size = map.size - 1; seed = map.seed }, ?removed)
        } else {
          let (newHamt, _) = Hamt.insert(map.hamt, hashed, newBucket);
          ({ hamt = newHamt; size = map.size - 1; seed = map.seed }, ?removed)
        }
      }
    };
  };

  public func delete<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K) : HashMap<K, V> {
    remove(map, hashFn, key).0
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///   );
  ///
  ///   assert HashMap.containsKey(map, HashMap.nat, 1);
  ///   assert not Map.containsKey(map, HashMap.nat, 3);
  /// }
  /// ```
  public func containsKey<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K) : Bool {
    get(map, hashFn, key) |> Option.isSome(_);
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///   );
  ///
  ///   for ((key, value) in HashMap.entries(map)) {
  ///     Debug.print(Nat.toText(key) # " => " # value);
  ///   }
  /// }
  /// ```
  public func entries<K, V>(map : HashMap<K, V>) : Iter.Iter<(K, V)> {
    let inner = Hamt.entries(map.hamt);
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///   );
  ///
  ///   for (key in HashMap.keys(map)) {
  ///     Debug.print(Nat.toText(key));
  ///   }
  /// }
  /// ```
  public func keys<K, V>(map : HashMap<K, V>) : Iter.Iter<K> {
    Iter.map(entries(map), func (e : (K, V)) : K = e.0);
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
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///   );
  ///
  ///   for (value in HashMap.values(map)) {
  ///     Debug.print(value);
  ///   }
  /// }
  /// ```
  public func values<K, V>(map : HashMap<K, V>) : Iter.Iter<V> {
    Iter.map(entries(map), func (e : (K, V)) : V = e.1);
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
  public func isEmpty<K, V>(map : HashMap<K, V>) : Bool {
    map.size == 0
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
  public func size<K, V>(map : HashMap<K, V>) : Nat {
    map.size
  };

  module Bucket {
    public type T<K, V> = [(K, V)];

    public func add<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K, value : V) : (T<K, V>, ?V) {
      var i : Nat = 0;
      let size = b.size();
      while (i < size) {
        let (k, v) = b[i];
        if (eq(k, key)) {
          let newBucket = Array.tabulate<(K, V)>(size, func j = if (i != j) b[j] else (key, value));
          return (newBucket, ?v)
        };
        i += 1;
      };
      let newBucket = Array.tabulate<(K, V)>(size + 1, func i = if (i != size) b[i] else (key, value));
      (newBucket, null)
    };

    public func get<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      var i : Nat = 0;
      let size = b.size();
      while (i < size) {
        let (k, v) = b[i];
        if (eq(k, key)) {
          return ?v;
        };
        i += 1;
      };
      null;
    };

    public func remove<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?(T<K, V>, V) {
      var i : Nat = 0;
      let size = b.size();
      while (i < size) {
        let (k, v) = b[i];
        if (eq(k, key)) {
          let newBucket = Array.tabulate<(K, V)>(size - 1, func ix = if (ix < i) b[ix] else b[ix + 1]);
          return ?(newBucket, v);
        };
        i += 1;
      };
      null;
    };
  };
}
