import Bench "mo:bench";
import Hashtable "mo:hashmap/Map";
import Sip13 "mo:siphash/Sip13";

import HashMap "../src/HashMap";
import PureHamt "../src/pure/Hamt";

import Blob "mo:core/Blob";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import PureMap "mo:core/pure/Map";

import OldHashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

module {
  public func init() : Bench.Bench {
    func sip32Blob(b : Blob) : Nat32 {
      Nat64.toNat32(Sip13.hashBlob((0, 0), b) >> 32)
    };

    func blob(n : Nat) : Blob {
      Text.encodeUtf8(Nat.toText(n));
    };

    func blobWrong(n : Nat) : Blob {
      Text.encodeUtf8("a" # Nat.toText(n));
    };

    let blobHashUtilsSip : Hashtable.HashUtils<Blob> = (sip32Blob, Blob.equal);

    let bench = Bench.Bench();

    bench.name("Comparing Hash-based and Ordered Maps");
    bench.description("Adds, retrieves, and deletes n map entries");

    bench.rows([
      "hamt/HashMap",
      "core/Map",
      "mops/Hashtable",

      "hamt/pure/HashMap",
      "core/pure/Map",

      "base/HashMap",
      "base/Trie",
    ]);
    bench.cols([
      "0",
      "100",
      "10000",
      "500000",
    ]);

    bench.runner(func(row, col) {
      let ?n = Nat.fromText(col) else { return };

      if (row == "hamt/HashMap") {
        let map : HashMap.HashMap<Blob, Nat> = HashMap.new((0 : Nat64, 0 : Nat64));
        for (i in Nat.range(1, n)) {
          ignore HashMap.insert(map, HashMap.blob, blob(i), i);
        };

        for (i in Nat.range(1, n)) {
          ignore HashMap.get(map, HashMap.blob, blob(i));
          ignore HashMap.get(map, HashMap.blob, blobWrong(i));
        };

        for (i in Nat.range(n + 1, n + n)) {
          ignore HashMap.remove(map, HashMap.blob, blob(i));
        };
      };

      if (row == "core/Map") {
        let map = Map.empty<Blob, Nat>();
        for (i in Nat.range(1, n)) {
          Map.add(map, Blob.compare, blob(i), i);
        };
        for (i in Nat.range(1, n)) {
          ignore Map.get(map, Blob.compare, blob(i));
          ignore Map.get(map, Blob.compare, blobWrong(i));
        };

        for (i in Nat.range(n + 1, n + n)) {
          Map.remove(map, Blob.compare, blob(i));
        };
      };

      if (row == "mops/Hashtable") {
        let map = Hashtable.new<Blob, Nat>();
        for (i in Nat.range(1, n)) {
          ignore Hashtable.put(map, blobHashUtilsSip, blob(i), i);
        };
        for (i in Nat.range(1, n)) {
          ignore Hashtable.get(map, blobHashUtilsSip, blob(i));
          ignore Hashtable.get(map, blobHashUtilsSip, blobWrong(i));
        };

        for (i in Nat.range(n + 1, n + n)) {
          ignore Hashtable.remove(map, blobHashUtilsSip, blob(i));
        };
      };

      if (row == "hamt/pure/HashMap") {
        let seed : (Nat64, Nat64) = (0, 0);
        var map = PureHamt.new<Nat>();
        for (i in Nat.range(1, n)) {
          map := PureHamt.add(map, Sip13.hashBlob(seed, blob(i)), i);
        };
        for (i in Nat.range(1, n)) {
          ignore PureHamt.get(map, Sip13.hashBlob(seed, blob(i)));
          ignore PureHamt.get(map, Sip13.hashBlob(seed, blobWrong(i)));
        };

        for (i in Nat.range(n + 1, n + n)) {
          let (newMap, _) = PureHamt.remove(map, Sip13.hashBlob(seed, blob(i)));
          map := newMap;
        };
      };

      if (row == "core/pure/Map") {
        var map = PureMap.empty<Blob, Nat>();
        for (i in Nat.range(1, n)) {
          map := PureMap.add(map, Blob.compare, blob(i), i);
        };
        for (i in Nat.range(1, n)) {
          ignore PureMap.get(map, Blob.compare, blob(i));
          ignore PureMap.get(map, Blob.compare, blobWrong(i));
        };

        for (i in Nat.range(n + 1, n + n)) {
          map := PureMap.remove(map, Blob.compare, blob(i));
        };
      };

      if (row == "base/HashMap") {
        let map = OldHashMap.HashMap<Blob, Nat>(0, Blob.equal, sip32Blob);
        for (i in Nat.range(1, n)) {
          map.put(blob(i), i);
        };
        for (i in Nat.range(1, n)) {
          ignore map.get(blob(i));
          ignore map.get(blobWrong(i));
        };

        for (i in Nat.range(n + 1, n + n)) {
          ignore map.remove(blob(i));
        };
      };

      if (row == "base/Trie") {
        func key(b: Blob) : Trie.Key<Blob> { { hash = sip32Blob(b); key = b } };
        var map : Trie.Trie<Blob, Nat> = Trie.empty();
        for (i in Nat.range(1, n)) {
          map := Trie.put(map, key(blob(i)), Blob.equal, i).0;
        };
        for (i in Nat.range(1, n)) {
          ignore Trie.get(map, key(blob(i)), Blob.equal);
          ignore Trie.get(map, key(blobWrong(i)), Blob.equal);
        };

        for (i in Nat.range(n + 1, n + n)) {
          map := Trie.remove(map, key(blob(i)), Blob.equal).0;
        };
      };

    });

    bench;
  };
};
