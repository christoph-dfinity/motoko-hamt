import Hamt "Hamt";
import AL "mo:base/AssocList";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Hasher "mo:siphash/Hasher";

module {
  /// A HashMap
  public type Map<K, V> = {
    hamt : Hamt.Hamt<Bucket.T<K, V>>;
  };

  public func new<K, V>() : Map<K, V> {
    { hamt = Hamt.new() };
  };

  public class Operations<K>(hasher : Hasher.Hasher, hash : (Hasher.Hasher, K) -> Hamt.Hash, eq : (K, K) -> Bool) {
    public func add<V>(map : Map<K, V>, key : K, value : V) {
      ignore swap(map, key, value);
    };

    public func swap<V>(map : Map<K, V>, key : K, value : V) : ?V {
      let hashed = hash(hasher, key);
      var previous : ?V = null;
      Hamt.upsert(map.hamt, hashed, func (prev : ?Bucket.T<K, V>) : Bucket.T<K, V> {
        switch (prev) {
          case null {
            { var items = List.make((key, value)) }
          };
          case (?bucket) {
            let replaced = Bucket.add(bucket, eq, key, value);
            previous := replaced;
            bucket
          };
        }
      });
      previous
    };

    public func remove<V>(map : Map<K, V>, key : K) : ?V {
      let hashed = hash(hasher, key);
      let ?bucket = Hamt.remove(map.hamt, hashed) else return null;
      let removed = Bucket.remove(bucket, eq, key);
      if (not List.isNil(bucket.items)) {
        Hamt.add(map.hamt, hashed, bucket)
      };
      removed
    };

    public func delete<V>(map : Map<K, V>, key : K) {
      ignore remove(map, key);
    };

    public func get<V>(map : Map<K, V>, key : K) : ?V {
      let hashed = hash(hasher, key);
      let ?bucket = Hamt.get(map.hamt, hashed) else return null;
      Bucket.get(bucket, eq, key)
    };

    public func entries<V>(map : Map<K, V>) : Iter.Iter<(K, V)> {
      let inner = Hamt.entries(map.hamt);
      let ?(_, initialBucket) = inner.next() else {
        return object { public func next() : ?(K, V) { return null } }
      };
      var currentBucket : Iter.Iter<(K, V)> = List.toIter(initialBucket.items);
      object {
        public func next() : ?(K, V) {
          let nextEntry = currentBucket.next();
          switch (nextEntry) {
            case null {
              let ?(_, nextBucket) = inner.next() else { return null };
              currentBucket := List.toIter(nextBucket.items);
              currentBucket.next();
            };
            case _ {
              nextEntry
            };
          };
        };
      };
    };
  };

  module Bucket {
    public type T<K, V> = {
      var items : AL.AssocList<K, V>;
    };

    public func add<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K, value : V) : ?V {
      let (newList, replaced) = AL.replace(b.items, key, eq, ?value);
      b.items := newList;
      replaced
    };

    public func get<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      AL.find(b.items, key, eq)
    };

    public func remove<K, V>(b : T<K, V>, eq : (K, K) -> Bool, key : K) : ?V {
      let (newList, replaced) = AL.replace(b.items, key, eq, null);
      b.items := newList;
      replaced
    };
  };
}
