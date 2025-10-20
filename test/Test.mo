import Hamt "../src/Hamt";
import HamtTest "Hamt";
import Hasher "mo:siphash/Hasher";
import M "mo:matchers/Matchers";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import PureHamt "../src/pure/Hamt";
import Runtime "mo:core/Runtime";
import S "mo:matchers/Suite";
import Sip13 "mo:siphash/Sip13";
import T "mo:matchers/Testable";

func natHash(n : Nat) : Nat64 {
  Sip13.withHasherUnkeyed(func h = Hasher.nat(h, n))
};

let suite = S.suite("HAMT", [
  S.test("add hashes with shared prefixes", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    ignore map.insert(64 : Nat64, 64);
    ignore map.insert(64 * 64: Nat64, 64 * 64);
    ignore map.insert(64 * 64 * 64: Nat64, 64 * 64 * 64);
    map.get(64 * 64 : Nat64);
  }, M.equals(T.optional(T.natTestable, ?(64 * 64)))),
  S.test("add overlapping hashes", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    map.insert(0 : Nat64, 1);
  }, M.equals(T.optional(T.natTestable, ?0))),
  S.test("remove", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    map.remove(0 : Nat64);
  }, M.equals(T.optional(T.natTestable, ?0))),
  S.test("remove non-existing", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    ignore map.remove(0 : Nat64);
    map.remove(0 : Nat64);
  }, M.equals(T.optional(T.natTestable, (null : ?Nat)))),
  S.test("remove from nested tree", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    ignore map.insert(64 : Nat64, 64);
    let removed = map.remove(0 : Nat64);
    let removed2 = map.remove(64 : Nat64);
    removed;
  }, M.equals(T.optional(T.natTestable, (?0 : ?Nat)))),
  S.test("full on", do {
    let map = Hamt.new<Nat>();
    for (i in Nat.range(1, 100)) {
      ignore map.insert(natHash(i), i);
    };

    var sum : Nat = 0;
    for (i in Nat.range(1, 100)) {
      let ?res = map.get(natHash(i)) else {
        Runtime.trap("failed to find: " # debug_show i);
      };
      sum += res;
    };
    for (i in Nat.range(101, 200)) {
      let null = map.get(natHash(i)) else {
        Runtime.trap("failed to find: " # debug_show i);
      };
    };
    sum
  }, M.equals(T.nat(4950))),
  S.test("Test compaction on remove", do {
    let map = Hamt.new<Nat>();
    ignore map.insert(0 : Nat64, 0);
    ignore map.insert(64 * 64 : Nat64, 64 * 64);
    let nestedDepth = Hamt.maxDepth(map);
    ignore map.remove(0 : Nat64);
    let depthAfterRemoval = map.maxDepth();
    (nestedDepth, depthAfterRemoval)
  }, M.equals(T.tuple2(T.natTestable, T.natTestable, (3, 1)))),
]);

let suitePure = S.suite("pure/HAMT", [
  S.test("Test compaction on remove", do {
    var map : PureHamt.Hamt<Nat> = PureHamt.new();
    map := PureHamt.add(map, 0 : Nat64, 0);
    map := PureHamt.add(map, 64 * 64 : Nat64, 64 * 64);
    let nestedDepth = PureHamt.maxDepth(map);
    let (newHamt, _) = PureHamt.remove(map, (0 : Nat64));
    let depthAfterRemoval = PureHamt.maxDepth(newHamt);
    (nestedDepth, depthAfterRemoval)
  }, M.equals(T.tuple2(T.natTestable, T.natTestable, (3, 1))))
]);

S.run(suite);
S.run(suitePure);
S.run(HamtTest.suite());
