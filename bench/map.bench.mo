import Bench "mo:bench";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Fnv "../src/Fnv";
import Hamt "../src/Map";
import PureHamt "../src/pure/Hamt";
import Hasher "mo:siphash/Hasher";
import Hashtable "mo:hashmap/Map";
import Iter "mo:base/Iter";
import OldHashMap "mo:base/HashMap";
import Map "mo:new-base/Map";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import PureMap "mo:new-base/pure/Map";
import Sip13 "mo:siphash/Sip13";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

module {

  public func init() : Bench.Bench {
    let hasher = Sip13.SipHasher13(13, 37);

    func fnv32Blob(b : Blob) : Nat32 {
      Fnv.hash32Blob(b)
    };

    func fnv64Blob(b : Blob) : Nat64 {
      Fnv.hash64Blob(b)
    };

    func sip32Blob(b : Blob) : Nat32 {
      hasher.reset();
      hasher.writeBlob(b);
      let hash = hasher.finish();
      Nat64.toNat32(hash >> 32)
    };

    func sip64Blob(b : Blob) : Nat64 {
      hasher.reset();
      hasher.writeBlob(b);
      hasher.finish();
    };

    func blob(n : Nat) : Blob {
      Text.encodeUtf8(Nat.toText(n));
    };

    func blobWrong(n : Nat) : Blob {
      Text.encodeUtf8("a" # Nat.toText(n));
    };

    let blobHashUtilsSip : Hashtable.HashUtils<Blob> = (sip32Blob, Blob.equal);
    let blobHashUtilsFnv : Hashtable.HashUtils<Blob> = (fnv32Blob, Blob.equal);

    let bench = Bench.Bench();

    bench.name("Comparing Hash-based and Ordered Maps");
    bench.description("Adds, retrieves, and deletes n map entries");

    bench.rows([
      "OrderedMap",

      "HAMT - Sip",
      "HAMT - Fnv",

      "Hashtable - Sip",
      "Hashtable - Fnv",

      "pure/Map",
      "pure/HAMT - Sip",
      "pure/HAMT - Fnv",

      "oldbase/HashMap - Sip",
      "oldbase/Trie - Sip",
    ]);
    bench.cols([
      "0",
      "100",
      "10000",
      "500000",
    ]);

    bench.runner(func(row, col) {
      let ?n = Nat.fromText(col);

      if (row == "HAMT - Sip") {
        let hamt = Hamt.new<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          ignore Hamt.add(sip64Blob, Blob.equal, hamt, blob(i), i);
        };

        for (i in Iter.range(1, n)) {
          ignore Hamt.get(sip64Blob, Blob.equal, hamt, blob(i));
          ignore Hamt.get(sip64Blob, Blob.equal, hamt, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore Hamt.remove(sip64Blob, Blob.equal, hamt, blob(i));
        };
      };

      if (row == "HAMT - Fnv") {
        let hamt = Hamt.new<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          ignore Hamt.add(fnv64Blob, Blob.equal, hamt, blob(i), i);
        };

        for (i in Iter.range(1, n)) {
          ignore Hamt.get(fnv64Blob, Blob.equal, hamt, blob(i));
          ignore Hamt.get(fnv64Blob, Blob.equal, hamt, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore Hamt.remove(fnv64Blob, Blob.equal, hamt, blob(i));
        };
      };

      if (row == "OrderedMap") {
        let map = Map.empty<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          Map.add(map, Blob.compare, blob(i), i);
        };
        for (i in Iter.range(1, n)) {
          ignore Map.get(map, Blob.compare, blob(i));
          ignore Map.get(map, Blob.compare, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore Map.remove(map, Blob.compare, blob(i));
        };
      };

      if (row == "pure/Map") {
        var map = PureMap.empty<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          map := PureMap.add(map, Blob.compare, blob(i), i);
        };
        for (i in Iter.range(1, n)) {
          ignore PureMap.get(map, Blob.compare, blob(i));
          ignore PureMap.get(map, Blob.compare, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          map := PureMap.remove(map, Blob.compare, blob(i));
        };
      };
      if (row == "pure/HAMT - Sip") {
        var map = PureHamt.new<Nat>();
        for (i in Iter.range(1, n)) {
          map := PureHamt.add(map, sip64Blob(blob(i)), i);
        };
        for (i in Iter.range(1, n)) {
          ignore PureHamt.get(map, sip64Blob(blob(i)));
          ignore PureHamt.get(map, sip64Blob(blobWrong(i)));
        };

        for (i in Iter.range(n + 1, n + n)) {
          let (newMap, _) = PureHamt.remove(map, sip64Blob(blob(i)));
          map := newMap;
        };
      };
      if (row == "pure/HAMT - Fnv") {
        var map = PureHamt.new<Nat>();
        for (i in Iter.range(1, n)) {
          map := PureHamt.add(map, fnv64Blob(blob(i)), i);
        };
        for (i in Iter.range(1, n)) {
          ignore PureHamt.get(map, fnv64Blob(blob(i)));
          ignore PureHamt.get(map, fnv64Blob(blobWrong(i)));
        };

        for (i in Iter.range(n + 1, n + n)) {
          let (newMap, _) = PureHamt.remove(map, fnv64Blob(blob(i)));
          map := newMap;
        };
      };

      if (row == "Hashtable - Sip") {
        let map = Hashtable.new<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          ignore Hashtable.put(map, blobHashUtilsSip, blob(i), i);
        };
        for (i in Iter.range(1, n)) {
          ignore Hashtable.get(map, blobHashUtilsSip, blob(i));
          ignore Hashtable.get(map, blobHashUtilsSip, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore Hashtable.remove(map, blobHashUtilsSip, blob(i));
        };
      };

      if (row == "Hashtable - Fnv") {
        let map = Hashtable.new<Blob, Nat>();
        for (i in Iter.range(1, n)) {
          ignore Hashtable.put(map, blobHashUtilsFnv, blob(i), i);
        };
        for (i in Iter.range(1, n)) {
          ignore Hashtable.get(map, blobHashUtilsFnv, blob(i));
          ignore Hashtable.get(map, blobHashUtilsFnv, blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore Hashtable.remove(map, blobHashUtilsFnv, blob(i));
        };
      };

      if (row == "oldbase/HashMap - Sip") {
        let map = OldHashMap.HashMap<Blob, Nat>(0, Blob.equal, sip32Blob);
        for (i in Iter.range(1, n)) {
          ignore map.put(blob(i), i);
        };
        for (i in Iter.range(1, n)) {
          ignore map.get(blob(i));
          ignore map.get(blobWrong(i));
        };

        for (i in Iter.range(n + 1, n + n)) {
          ignore map.remove(blob(i));
        };
      };

      if (row == "oldbase/Trie - Sip") {
        func key(b: Blob) : Trie.Key<Blob> { { hash = sip32Blob(b); key = b } };
        var map : Trie.Trie<Blob, Nat> = Trie.empty();
        for (i in Iter.range(1, n)) {
          map := Trie.put(map, key(blob(i)), Blob.equal, i).0;
        };
        for (i in Iter.range(1, n)) {
          ignore Trie.get(map, key(blob(i)), Blob.equal);
          ignore Trie.get(map, key(blobWrong(i)), Blob.equal);
        };

        for (i in Iter.range(n + 1, n + n)) {
          map := Trie.remove(map, key(blob(i)), Blob.equal).0;
        };
      };

    });

    bench;
  };
};
