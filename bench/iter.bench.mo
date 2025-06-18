import Array "mo:base/Array";
import Bench "mo:bench";
import Blob "mo:base/Blob";
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
      "HAMT",
    ]);
    bench.cols([
      "100000",
    ]);


    let N : Nat = 100_000;
    let keys: [Blob] = Array.tabulate(N + 1, blob);

    let hamt = Hamt.new<Blob, Nat>();
    let blobMap = Hamt.Operations<Blob>(Sip13.SipHasher13(0, 0), hashBlob64, Blob.equal);
    for (i in Iter.range(1, N)) {
      blobMap.add(hamt, keys[i], i);
    };

    let orderedMap = Map.empty<Blob, Nat>();
    for (i in Iter.range(1, N)) {
      Map.add(orderedMap, Blob.compare, keys[i], i);
    };

    bench.runner(func(row, col) {
      let ?n = Nat.fromText(col);

      if (row == "HAMT") {
        var count : Nat = 0;
        for ((k, v) in blobMap.entries(hamt)) {
          count += 1;
        };
        assert count == N;
      };
      if (row == "OrderedMap") {
        var count : Nat = 0;
        for ((k, v) in Map.entries(orderedMap)) {
          count += 1;
        };
        assert count == N;
      };
    });

    bench;
  };
};
