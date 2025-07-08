import AL "mo:base/AssocList";
import Blob "mo:base/Blob";
import Hamt "Hamt";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Sip13 "mo:siphash/Sip13";
import Text "mo:base/Text";

module {
  /// A HashMap
  public type Map<K, V> = {
    hamt : Hamt.Hamt<Bucket.T<K, V>>;
    var size : Nat;
    seed : (Nat64, Nat64);
  };

  /// Holds both a hash and equality function for the Map's key type
  public type HashFn<K> = (hash : ((Nat64, Nat64), K) -> Nat64, eq : (K, K) -> Bool);
  public let blob = (Sip13.hashBlob, Blob.equal);
  public let text = (Sip13.hashText, Text.equal);
  public let nat = (Sip13.hashNat, Nat.equal);
  public let int = (Sip13.hashInt, Int.equal);

  public func new<K, V>(seed : (Nat64, Nat64)) : Map<K, V> {
    { hamt = Hamt.new(); var size = 0; seed };
  };

  public func singleton<K, V>(seed : (Nat64, Nat64), hashFn : HashFn<K>, key : K, value : V) : Map<K, V> {
    let hashed = hashFn.0(seed, key);
    { hamt = Hamt.singleton(hashed, { var items = List.make((key, value)) }); var size = 1; seed };
  };

  public func fromIter<K, V>(seed : (Nat64, Nat64), hashFn : HashFn<K>, iter : Iter.Iter<(K, V)>) : Map<K, V> {
    let map : Map<K, V> = new(seed);
    for ((k, v) in iter) {
      ignore insert(map, hashFn, k, v);
    };
    map
  };

  public func insert<K, V>(map : Map<K, V>, hashFn : HashFn<K>, key : K, value : V) : ?V {
    let hashed = hashFn.0(map.seed, key);
    var previous : ?V = null;
    Hamt.upsert(map.hamt, hashed, func (prev : ?Bucket.T<K, V>) : Bucket.T<K, V> {
      switch (prev) {
        case null {
          { var items = List.make((key, value)) }
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

  public func get<K, V>(map : Map<K, V>, hashFn : HashFn<K>, key : K) : ?V {
    let hashed = hashFn.0(map.seed, key);
    let ?bucket = Hamt.get(map.hamt, hashed) else return null;
    Bucket.get(bucket, hashFn.1, key)
  };

  public func remove<K, V>(map : Map<K, V>, hashFn : HashFn<K>, key : K) : ?V {
    let hashed = hashFn.0(map.seed, key);
    let ?bucket = Hamt.remove(map.hamt, hashed) else return null;
    let removed = Bucket.remove(bucket, hashFn.1, key);
    if (not List.isNil(bucket.items)) {
      Hamt.add(map.hamt, hashed, bucket)
    };
    if (Option.isSome(removed)) {
      map.size -= 1;
    };
    removed
  };

  public func containsKey<K, V>(hashFn : HashFn<K>, map : Map<K, V>, key : K) : Bool {
    get(map, hashFn, key) |> Option.isSome(_);
  };

  public func entries<K, V>(map : Map<K, V>) : Iter.Iter<(K, V)> {
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

  public func keys<K, V>(map : Map<K, V>) : Iter.Iter<K> {
    Iter.map(entries(map), func (e : (K, V)) : K = e.0);
  };

  public func values<K, V>(map : Map<K, V>) : Iter.Iter<V> {
    Iter.map(entries(map), func (e : (K, V)) : V = e.1);
  };

  public func size<K, V>(map : Map<K, V>) : Nat {
    map.size
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
