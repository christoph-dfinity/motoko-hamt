import Iter "mo:base/Iter";
import Map "Map";
import Hamt "Hamt";
import Hasher "mo:siphash/Hasher";

module {
  public class Operations<K>(hasher : Hasher.Hasher, hash : (Hasher.Hasher, K) -> Hamt.Hash, eq : (K, K) -> Bool) {

    let hashFn : Map.HashFn<K> = (func (k : K) : Hamt.Hash = hash(hasher, k), eq);

    public func new<V>() : Map.Map<K, V> = Map.new();

    public func singleton<V>(key : K, value : V) : Map.Map<K, V> =
      Map.singleton(hashFn, key, value);

    public func fromIter<V>(iter : Iter.Iter<(K, V)>) : Map.Map<K, V> =
      Map.fromIter(hashFn, iter);

    public func insert<V>(map : Map.Map<K, V>, key : K, value : V) : ?V =
      Map.insert(hashFn, map, key, value);

    public func get<V>(map : Map.Map<K, V>, key : K) : ?V =
      Map.get(hashFn, map, key);

    public func remove<V>(map : Map.Map<K, V>, key : K) : ?V =
      Map.remove(hashFn, map, key);

    public func containsKey<V>(map : Map.Map<K, V>, key : K) : Bool =
      Map.containsKey(hashFn, map, key);

    public func entries<V>(map : Map.Map<K, V>) : Iter.Iter<(K, V)> = Map.entries(map);
    public func keys<V>(map : Map.Map<K, V>) : Iter.Iter<K> = Map.keys(map);
    public func values<V>(map : Map.Map<K, V>) : Iter.Iter<V> = Map.values(map);
    public func size<V>(map : Map.Map<K, V>) : Nat = Map.size(map);
  };
}
