import Array "mo:base/Array";
import Bench "mo:bench";
import Blob "mo:base/Blob";
import Fnv "../src/Fnv";
import Ops "../src/Operations";
import Hamt "../src/Map";
import Hasher "mo:siphash/Hasher";
import Iter "mo:base/Iter";
import Map "mo:new-base/Map";
import Nat "mo:base/Nat";
import Sip13 "mo:siphash/Sip13";
import Text "mo:base/Text";

module {

  public func init() : Bench.Bench {
    func hashBlob64(hasher : Hasher.Hasher, b : Blob) : Nat64 {
      hasher.reset();
      hasher.writeBlob(b);
      hasher.finish();
    };

    func blob(n : Nat) : Blob {
      Text.encodeUtf8(Nat.toText(n));
    };

    let bench = Bench.Bench();

    bench.name("Iterating through HAMTs");
    bench.description("Measures the iteration speed");

    bench.rows([
      "OrderedMap",
      "HAMT - Sip",
      "HAMT - Fnv",
    ]);
    bench.cols([
      "100000",
    ]);


    let N : Nat = 100_000;
    let keys: [Blob] = Array.tabulate(N + 1, blob);

    let orderedMap = Map.empty<Blob, Nat>();
    for (i in Iter.range(1, N)) {
      Map.add(orderedMap, Blob.compare, keys[i], i);
    };

    let fnvMap = Ops.Operations<Blob>(Fnv.FnvHasher(), hashBlob64, Blob.equal);
    let fnvHamt : Hamt.Map<Blob, Nat> = fnvMap.new();
    for (i in Iter.range(1, N)) {
      ignore fnvMap.insert(fnvHamt, keys[i], i);
    };

    let sipMap = Ops.Operations<Blob>(Sip13.SipHasher13(0, 0), hashBlob64, Blob.equal);
    let sipHamt : Hamt.Map<Blob, Nat> = sipMap.new();
    for (i in Iter.range(1, N)) {
      ignore sipMap.insert(sipHamt, keys[i], i);
    };

    bench.runner(func(row, _) {
      if (row == "OrderedMap") {
        var count : Nat = 0;
        for ((k, v) in Map.entries(orderedMap)) {
          count += 1;
        };
        assert count == N;
      };
      if (row == "HAMT - Sip") {
        var count : Nat = 0;
        for ((k, v) in sipMap.entries(sipHamt)) {
          count += 1;
        };
        assert count == N;
      };
      if (row == "HAMT - Fnv") {
        var count : Nat = 0;
        for ((k, v) in fnvMap.entries(fnvHamt)) {
          count += 1;
        };
        assert count == N;
      };
    });

    bench;
  };
};
