/// Imperative Key-Value HashMaps

// TODO: Implement equals

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
import VarArray "mo:core/VarArray";

module {
  /// An imperative key-value hash map.
  /// The map data structure type is stable and can be used for orthogonal persistence.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
  ///
  /// persistent actor {
  ///   // creation
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.new<Nat, Text>(seed);
  ///   // insertion
  ///   ignore HashMap.insert(map, HashMap.nat, 0, "Zero");
  ///   // retrieval
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == null;
  ///   // removal
  ///   ignore HashMap.remove(map, HashMap.nat, 0);
  ///   assert HashMap.isEmpty(map);
  /// }
  /// ```
  ///
  /// The internal implementation is a [Hash Array Mapped Trie] with 64bit hash keys and
  /// linked lists in the leafs. The main advantage over a traditional hashtable is that
  /// the performance of insertion/removal is not amortized, as there's no need for
  /// resizing/rehashing, meaning we avoid the risk of hitting the instruction
  /// limit for very large maps.
  ///
  /// The provided hashing functions (Sip13) are HashDoS resistant as long as the map is
  /// seeded with secure randomness.
  /// [Hash Array Mapped Trie]: https://lampwww.epfl.ch/papers/idealhashtrees.pdf
  public type HashMap<K, V> = {
    hamt : Hamt.Hamt<Bucket.T<K, V>>;
    var size : Nat;
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

  /// Create a new empty mutable HashMap.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.new<Nat, Text>(seed);
  ///   assert HashMap.size(map) == 0;
  /// }
  /// ```
  public func new<K, V>(seed : Seed) : HashMap<K, V> {
    { hamt = Hamt.new(); var size = 0; seed };
  };

  /// Create a new mutable HashMap with a single entry.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
  /// import Iter "mo:core/Iter";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.singleton<Nat, Text>(seed, HashMap.nat, 0, "Zero");
  ///   assert Iter.toArray(HashMap.entries(map)) == [(0, "Zero")];
  /// }
  /// ```
  public func singleton<K, V>(seed : Seed, hashFn : HashFn<K>, key : K, value : V) : HashMap<K, V> {
    let hashed = hashFn.0(seed, key);
    { hamt = Hamt.singleton(hashed, { var items = [var (key, value)] }); var size = 1; seed };
  };

  /// Create a mutable HashMap with the entries obtained from an iterator.
  /// If the iterator produces any pairs with equal keys, only one of the corresponding values will be inserted.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
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
    let map : HashMap<K, V> = new(seed);
    for ((k, v) in iter) {
      ignore insert(map, hashFn, k, v);
    };
    map
  };

  /// Given `map` hashed with `hashFn`, insert a new mapping from `key` to `value`.
  ///
  /// If the map did not have this key present, null is returned.
  /// If the map did have this key present, the value is updated, and the old value is returned.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.new<Nat, Text>(seed);
  ///   assert HashMap.insert(map, HashMap.nat, 0, "Zero") == null;
  ///   assert HashMap.insert(map, HashMap.nat, 1, "One") == null;
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 1) == ?"One";
  ///
  ///   assert HashMap.insert(map, HashMap.nat, 0, "Nil") == ?"Zero";
  ///   assert HashMap.get(map, HashMap.nat, 0) == ?"Nil";
  /// }
  /// ```
  public func insert<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K, value : V) : ?V {
    let hashed = hashFn.0(map.seed, key);
    var previous : ?V = null;
    Hamt.upsert(map.hamt, hashed, func (prev) {
      switch (prev) {
        case null {
          { var items = [var (key, value)] }
        };
        case (?bucket) {
          let replaced = Bucket.add(bucket, hashFn.1, key, value);
          previous := replaced;
          bucket
        };
      }
    });
    if (Option.isNull(previous)) {
      map.size += 1;
    };
    previous
  };

  /// Get the value associated with key in the given map if present and `null` otherwise.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
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

  /// Delete an entry by its key in the map.
  /// No effect if the key is not present.
  ///
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
  /// import Iter "mo:core/Iter";
  ///
  /// persistent actor {
  ///   let seed : HashMap.Seed = (0, 0);
  ///   let map = HashMap.fromIter<Nat, Text>(
  ///     seed, HashMap.nat,
  ///     [(0, "Zero"), (2, "Two"), (1, "One")].values(),
  ///   );
  ///
  ///   assert HashMap.remove(map, HashMap.nat, 1) = ?"One";
  ///   assert HashMap.get(map, HashMap.nat, 1) = null;
  ///   assert HashMap.size(map) == 2;
  ///   assert HashMap.remove(map, HashMap.nat, 42) == null;
  ///   assert HashMap.size(map) == 2;
  /// }
  /// ```
  public func remove<K, V>(map : HashMap<K, V>, hashFn : HashFn<K>, key : K) : ?V {
    let hashed = hashFn.0(map.seed, key);
    let ?bucket = Hamt.remove(map.hamt, hashed) else return null;
    let removed = Bucket.remove(bucket, hashFn.1, key);
    if (not (bucket.items.size() == 0)) {
      ignore Hamt.insert(map.hamt, hashed, bucket)
    };
    if (Option.isSome(removed)) {
      map.size -= 1;
    };
    removed
  };

  /// Tests whether the map contains the provided key.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
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
  /// import HashMap "mo:hamt/HashMap";
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
    var currentBucket : Iter.Iter<(K, V)> = initialBucket.items.values();
    object {
      public func next() : ?(K, V) {
        let nextEntry = currentBucket.next();
        switch (nextEntry) {
          case null {
            let ?(_, nextBucket) = inner.next() else { return null };
            currentBucket := nextBucket.items.values();
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
  /// import HashMap "mo:hamt/HashMap";
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
    Iter.map(entries(map), func (e) = e.0);
  };

  /// Returns an iterator over the values in the map, traversing the entries in arbitary order.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
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
    Iter.map(entries(map), func e = e.1);
  };

  /// Determines whether a key-value map is empty.
  ///
  /// Example:
  /// ```motoko
  /// import HashMap "mo:hamt/HashMap";
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
  /// import HashMap "mo:hamt/HashMap";
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
    public type T<K, V> = {
      var items : [var (K, V)];
    };

    public func add<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K, value : V) : ?V {
      var i : Nat = 0;
      let size = b.items.size();
      while (i < size) {
        let (k, v) = b.items[i];
        if (eq(k, key)) {
          b.items[i] := (key, value);
          return ?v
        };
        i += 1;
      };
      b.items := VarArray.tabulate(size + 1, func i = if (i != size) b.items[i] else (key, value));
      null
    };

    public func get<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      var i : Nat = 0;
      let size = b.items.size();
      while (i < size) {
        let (k, v) = b.items[i];
        if (eq(k, key)) {
          return ?v
        };
        i += 1;
      };
      null
    };

    public func remove<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      var i : Nat = 0;
      let size = b.items.size();
      while (i < size) {
        let (k, v) = b.items[i];
        if (eq(k, key)) {
          b.items := VarArray.tabulate(size - 1 : Nat, func ix = if (ix < i) b.items[ix] else b.items[ix + 1]);
          return ?v
        };
        i += 1;
      };
      null
    };
  };
}
