import Debug "mo:base/Debug";
import M "mo:matchers/Matchers";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import S "mo:matchers/Suite";
import T "mo:matchers/Testable";
import Sip13 "mo:siphash/Sip13";
import Hasher "mo:siphash/Hasher";

import Hamt "../src/Hamt";
import PureHamt "../src/pure/Hamt";

func natHash(n : Nat) : Nat64 {
  Sip13.withHasherUnkeyed(func h = Hasher.nat(h, n))
};

let suite = S.suite("HAMT", [
  S.test("add hashes with shared prefixes", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, (0 : Nat64), 0);
    ignore Hamt.insert(hamt, (64 : Nat64), 64);
    ignore Hamt.insert(hamt, (64 * 64: Nat64), 64 * 64);
    ignore Hamt.insert(hamt, (64 * 64 * 64: Nat64), 64 * 64 * 64);
    Hamt.get(hamt, (64 * 64 : Nat64));
  }, M.equals(T.optional(T.natTestable, ?(64 * 64)))),
  S.test("add overlapping hashes", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, (0 : Nat64), 0);
    Hamt.insert(hamt, (0 : Nat64), 1);
  }, M.equals(T.optional(T.natTestable, ?0))),
  S.test("remove", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, (0 : Nat64), 0);
    Hamt.remove(hamt, (0 : Nat64));
  }, M.equals(T.optional(T.natTestable, ?0))),
  S.test("remove non-existing", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, (0 : Nat64), 0);
    ignore Hamt.remove(hamt, (0 : Nat64));
    Hamt.remove(hamt, (0 : Nat64));
  }, M.equals(T.optional(T.natTestable, (null : ?Nat)))),
  S.test("remove from nested tree", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, (0 : Nat64), 0);
    ignore Hamt.insert(hamt, (64 : Nat64), 64);
    Debug.print(Hamt.showStructure(hamt));
    let removed = Hamt.remove(hamt, (0 : Nat64));
    Debug.print(Hamt.showStructure(hamt));
    let removed2 = Hamt.remove(hamt, (64 : Nat64));
    Debug.print(Hamt.showStructure(hamt));
    removed;
  }, M.equals(T.optional(T.natTestable, (?0 : ?Nat)))),
  S.test("full on", do {
    let hamt = Hamt.new<Nat>();
    for (i in Iter.range(1, 100)) {
      ignore Hamt.insert(hamt, natHash(i), i);
    };

    var sum : Nat = 0;
    for (i in Iter.range(1, 100)) {
      let ?res = Hamt.get(hamt, natHash(i)) else {
        Debug.print("failed to find: " # debug_show i);
        Debug.trap("args");
      };
      sum += res;
    };
    for (i in Iter.range(101, 200)) {
      let null = Hamt.get(hamt, natHash(i)) else {
        Debug.print("found: " # debug_show i);
        Debug.trap("args");
      };
    };
    sum
  }, M.equals(T.nat(5050))),
  S.test("Test compaction on remove", do {
    let hamt = Hamt.new<Nat>();
    ignore Hamt.insert(hamt, 0 : Nat64, 0);
    ignore Hamt.insert(hamt, (64 * 64 : Nat64), 64 * 64);
    let nestedDepth = Hamt.maxDepth(hamt);
    ignore Hamt.remove(hamt, (0 : Nat64));
    let depthAfterRemoval = Hamt.maxDepth(hamt);
    (nestedDepth, depthAfterRemoval)
  }, M.equals(T.tuple2(T.natTestable, T.natTestable, (3, 1)))),
]);

let suitePure = S.suite("pure/HAMT", [
  S.test("Test compaction on remove", do {
    var hamt : PureHamt.Hamt<Nat> = PureHamt.new();
    hamt := PureHamt.add(hamt, 0 : Nat64, 0);
    hamt := PureHamt.add(hamt, 64 * 64 : Nat64, 64 * 64);
    let nestedDepth = PureHamt.maxDepth(hamt);
    let (newHamt, _) = PureHamt.remove(hamt, (0 : Nat64));
    let depthAfterRemoval = PureHamt.maxDepth(newHamt);
    (nestedDepth, depthAfterRemoval)
  }, M.equals(T.tuple2(T.natTestable, T.natTestable, (3, 1))))
]);

S.run(suite);
S.run(suitePure);
