import Hamt "Hamt";
import AL "mo:base/AssocList";
import List "mo:base/List";

module {
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

  public type Map<K, V> = Hamt.Hamt<Bucket.T<K, V>>;

  public func new<K, V>() : Map<K, V> {
    Hamt.new()
  };

  public func add<K, V>(hash : K -> Hamt.Hash, eq : (K, K) -> Bool, map : Map<K, V>, key : K, value : V) {
    ignore replace(hash, eq, map, key, value);
  };

  public func replace<K, V>(hash : K -> Hamt.Hash, eq : (K, K) -> Bool, map : Map<K, V>, key : K, value : V) : ?V {
    let hashed = hash(key);
    let bucket = Hamt.get(map, hashed);
    switch (bucket) {
      case null {
        ignore Hamt.add(map, hashed, { var items = List.make((key, value)) });
        return null
      };
      case (?bucket) {
        return Bucket.add(bucket, eq, key, value)
      };
    };
  };

  public func remove<K, V>(hash : K -> Hamt.Hash, eq : (K, K) -> Bool, map : Map<K, V>, key : K) : ?V {
    let hashed = hash(key);
    let ?bucket = Hamt.get(map, hashed) else return null;
    let removed = Bucket.remove(bucket, eq, key);
    if (List.isNil(bucket.items)) {
      ignore Hamt.remove(map, hashed)
    };
    removed
  };

  public func get<K, V>(hash : K -> Hamt.Hash, eq : (K, K) -> Bool, map : Map<K, V>, key : K) : ?V {
    let hashed = hash(key);
    let ?bucket = Hamt.get(map, hashed) else return null;
    Bucket.get(bucket, eq, key)
  };
}
