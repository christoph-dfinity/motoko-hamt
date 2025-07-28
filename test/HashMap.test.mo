// @testmode wasi
import Suite "mo:matchers/Suite";
import T "mo:matchers/Testable";
import M "mo:matchers/Matchers";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Option "mo:core/Option";
import HashMap "../src/HashMap";

let { run; test; suite } = Suite;

let entryTestable : T.Testable<(Nat, Text)> = T.tuple2Testable(T.natTestable, T.textTestable);

type HashMap<K, V> = HashMap.HashMap<K, V>;

func empty<K,V>() : HashMap<K, V> {
  HashMap.new((0, 0) : HashMap.Seed)
};

func singleton<V>(key : Nat, v : V) : HashMap<Nat, V> {
  HashMap.singleton((0, 0) : HashMap.Seed, HashMap.nat, key, v)
};

func sortedEntries<V>(map : HashMap<Nat, V>) : [(Nat, V)] {
  Array.sort(
    Iter.toArray(HashMap.entries(map)),
    func (e1, e2) = Nat.compare(e1.0, e2.0)
  )
};

run(
  suite(
    "empty",
    [
      test(
        "size",
        HashMap.size(empty<Nat, Text>()),
        M.equals(T.nat(0))
      ),
      test(
        "is empty",
        HashMap.isEmpty(empty<Nat, Text>()),
        M.equals(T.bool(true))
      ),
      test(
        "add empty",
        do {
          let map = empty<Nat, Text>();
          ignore HashMap.insert(map, HashMap.nat, 0, "0");
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "insert empty",
        do {
          let map = empty<Nat, Text>();
          assert HashMap.insert(map, HashMap.nat, 0, "0") |> Option.isNull(_);
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "remove empty",
        do {
          let map = empty<Nat, Text>();
          ignore HashMap.remove(map, HashMap.nat, 0);
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove empty",
        do {
          let map = empty<Nat, Text>();
          assert (HashMap.remove(map, HashMap.nat, 0) |> Option.isNull(_));
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "take absent",
        do {
          let map = empty<Nat, Text>();
          HashMap.remove(map, HashMap.nat, 0)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "TODO: iterate forward",
        Iter.toArray(HashMap.entries(empty<Nat, Text>())),
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "contains key",
        do {
          let map = empty<Nat, Text>();
          HashMap.containsKey(map, HashMap.nat, 0)
        },
        M.equals(T.bool(false))
      ),
      test(
        "get absent",
        do {
          let map = empty<Nat, Text>();
          HashMap.get(map, HashMap.nat, 0)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update absent",
        do {
          let map = empty<Nat, Text>();
          HashMap.insert(map, HashMap.nat, 0, "0")
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "clear",
        do {
          let map = empty<Nat, Text>();
          HashMap.isEmpty(map)
        },
        M.equals(T.bool(true))
      ),
      test(
        "equal",
        do {
          let map1 = empty<Nat, Text>();
          let map2 = empty<Nat, Text>();
          // TODO
          // HashMap.equal(map1, map2, HashMap.nat, Text.equal)
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "from iterator",
        do {
          let map : HashMap.HashMap<Nat, Text> = HashMap.fromIter(
            // Still need this annotation. Would be neat if we could somehow put it in checking position?
            (0, 0) : HashMap.Seed,
            HashMap.nat,
            Iter.fromArray([])
          );
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      // test(
      //   "TODO to text",
      //   do {
      //     let map = empty<Nat, Text>();
      //     HashMap.toText<Nat, Text>(map, Nat.toText, func(value) { value })
      //   },
      //   M.equals(T.text("Map{}"))
      // ),
      // test(
      //   "compare",
      //   do {
      //     let map1 = empty<Nat, Text>();
      //     let map2 = empty<Nat, Text>();
      //     assert (HashMap.compare(map1, map2, HashMap.nat, Text.compare) == #equal);
      //     true
      //   },
      //   M.equals(T.bool(true))
      // ),
      // TODO: Test freeze and thaw
    ]
  )
);

run(
  suite(
    "singleton",
    [
      test(
        "size",
        HashMap.size<Nat, Text>(singleton(0, "0")),
        M.equals(T.nat(1))
      ),
      test(
        "is empty",
        HashMap.isEmpty<Nat, Text>(singleton(0, "0")),
        M.equals(T.bool(false))
      ),
      test(
        "add singleton old",
        do {
          let map = singleton<Text>(0, "0");
          ignore HashMap.insert(map, HashMap.nat, 0, "1");
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "1")]))
      ),
      test(
        "add singleton new",
        do {
          let map = singleton<Text>(0, "0");
          ignore HashMap.insert(map, HashMap.nat, 1, "1");
          // for (entry in Hamt.entries(map.hamt)) {
          //   Debug.print(debug_show entry)
          // };
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0"), (1, "1")]))
      ),
      test(
        "insert singleton old",
        do {
          let map = singleton<Text>(0, "0");
          assert (HashMap.insert(map, HashMap.nat, 0, "1") == ?"0");
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "1")]))
      ),
      test(
        "insert singleton new",
        do {
          let map = singleton<Text>(0, "0");
          assert HashMap.insert(map, HashMap.nat, 1, "1") == null;
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0"), (1, "1")]))
      ),
      test(
        "remove singleton old",
        do {
          let map = singleton<Text>(0, "0");
          ignore HashMap.remove(map, HashMap.nat, 0);
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove singleton new",
        do {
          let map = singleton<Text>(0, "0");
          ignore HashMap.remove(map, HashMap.nat, 1);
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "remove singleton old",
        do {
          let map = singleton<Text>(0, "0");
          assert HashMap.remove(map, HashMap.nat, 0) != null;
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove singleton new",
        do {
          let map = singleton<Text>(0, "0");
          assert HashMap.remove(map, HashMap.nat, 1) == null;
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "take function result",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.remove(map, HashMap.nat, 0)
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "take map result",
        do {
          let map = singleton<Text>(0, "0");
          ignore HashMap.remove(map, HashMap.nat, 0);
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      test(
        "contains present key",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.containsKey(map, HashMap.nat, 0)
        },
        M.equals(T.bool(true))
      ),
      test(
        "contains absent key",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.containsKey(map, HashMap.nat, 1)
        },
        M.equals(T.bool(false))
      ),
      test(
        "get present",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.get(map, HashMap.nat, 0)
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "get absent",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.get(map, HashMap.nat, 1)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update present",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.insert(map, HashMap.nat, 0, "Zero")
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "update absent",
        do {
          let map = singleton<Text>(0, "0");
          HashMap.insert(map, HashMap.nat, 1, "1")
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "replace if exists present",
        do {
          let map = singleton<Text>(0, "0");
          assert (HashMap.insert(map, HashMap.nat, 0, "Zero") == ?"0");
          HashMap.size(map)
        },
        M.equals(T.nat(1))
      ),
      test(
        "remove",
        do {
          let map = singleton<Text>(0, "0");
          assert HashMap.remove(map, HashMap.nat, 0) == ?"0";
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      // test(
      //   "TODO equal",
      //   do {
      //     let map1 = singleton<Text>(0, "0");
      //     let map2 = singleton<Text>(0, "0");
      //     HashMap.equal(map1, map2, HashMap.nat, Text.equal)
      //   },
      //   M.equals(T.bool(true))
      // ),
      // test(
      //   "TODO not equal",
      //   do {
      //     let map1 = singleton<Text>(0, "0");
      //     let map2 = singleton<Text>(1, "1");
      //     HashMap.equal(map1, map2, HashMap.nat, Text.equal)
      //   },
      //   M.equals(T.bool(false))
      // ),
    ]
  )
);

let smallSize = 100;
func smallMap() : HashMap<Nat, Text> {
  let map = empty<Nat, Text>();
  for (index in Nat.range(0, smallSize)) {
    ignore HashMap.insert(map, HashMap.nat, index, Nat.toText(index))
  };
  map
};

run(
  suite(
    "small map",
    [
      test(
        "size",
        HashMap.size(smallMap()),
        M.equals(T.nat(smallSize))
      ),
      test(
        "is empty",
        HashMap.isEmpty(smallMap()),
        M.equals(T.bool(false))
      ),
      test(
        "iterate forward",
        sortedEntries(smallMap()),
        M.equals(
          T.array(
            entryTestable,
            Array.tabulate(smallSize, func(index) { (index, Nat.toText(index)) })
          )
        )
      ),
      test(
        "contains absent key",
        do {
          let map = smallMap();
          HashMap.containsKey(map, HashMap.nat, smallSize)
        },
        M.equals(T.bool(false))
      ),
      test(
        "get present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "get absent",
        do {
          let map = smallMap();
          HashMap.get(map, HashMap.nat, smallSize)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (HashMap.insert(map, HashMap.nat, index, Nat.toText(index) # "!") == ?Nat.toText(index))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "update absent",
        do {
          let map = smallMap();
          HashMap.insert(map, HashMap.nat, smallSize, Nat.toText(smallSize))
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "replace if exists present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (HashMap.insert(map, HashMap.nat, index, Nat.toText(index) # "!") == ?Nat.toText(index))
          };
          HashMap.size(map)
        },
        M.equals(T.nat(smallSize))
      ),
      test(
        "remove",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert HashMap.remove(map, HashMap.nat, index) != null
          };
          HashMap.isEmpty(map)
        },
        M.equals(T.bool(true))
      ),
      // test(
      //   "TODO equal",
      //   do {
      //     let map1 = smallMap();
      //     let map2 = smallMap();
      //     HashMap.equal(map1, map2, HashMap.nat, Text.equal)
      //   },
      //   M.equals(T.bool(true))
      // ),
      // test(
      //   "not equal",
      //   do {
      //     let map1 = smallMap();
      //     let map2 = smallMap();
      //     assert HashMap.remove(map2, HashMap.nat, smallSize - 1 : Nat) != null;
      //     HashMap.equal(map1, map2, HashMap.nat, Text.equal)
      //   },
      //   M.equals(T.bool(false))
      // ),
      // test(
      //   "from iterator",
      //   do {
      //     let array = Array.tabulate<(Nat, Text)>(smallSize, func(index) { (index, Nat.toText(index)) });
      //     let map = HashMap.fromIter<Nat, Text>((0, 0) : HashMap.Seed, HashMap.nat, Iter.fromArray(array));
      //     for (index in Nat.range(0, smallSize)) {
      //       assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
      //     };
      //     assert (HashMap.equal(map, smallMap(), HashMap.nat, Text.equal));
      //     HashMap.size(map)
      //   },
      //   M.equals(T.nat(smallSize))
      // ),
    ]
  )
);

// TODO: Use PRNG in new core library
class Random(seed : Nat) {
  var number = seed;

  public func reset() {
    number := seed
  };

  public func next() : Nat {
    number := (123138118391 * number + 133489131) % 9999;
    number
  }
};

let randomSeed = 4711;
let numberOfEntries = 10_000;

run(
  suite(
    "large map",
    [
      test(
        "add",
        do {
          let map = empty<Nat, Text>();
          for (index in Nat.range(0, numberOfEntries)) {
            ignore HashMap.insert(map, HashMap.nat, index, Nat.toText(index));
            assert (HashMap.size(map) == index + 1);
            assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
          };
          for (index in Nat.range(0, numberOfEntries)) {
            assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
          };
          assert (HashMap.get(map, HashMap.nat, numberOfEntries) == null);
          HashMap.size(map)
        },
        M.equals(T.nat(numberOfEntries))
      ),
      test(
        "insert",
        do {
          let map = empty<Nat, Text>();
          for (index in Nat.range(0, numberOfEntries)) {
            assert HashMap.insert(map, HashMap.nat, index, Nat.toText(index)) == null;
            assert (HashMap.size(map) == index + 1);
            assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
          };
          for (index in Nat.range(0, numberOfEntries)) {
            assert (HashMap.insert(map, HashMap.nat, index, Nat.toText(index))) != null;
            assert (HashMap.get(map, HashMap.nat, index) == ?Nat.toText(index))
          };
          assert (HashMap.get(map, HashMap.nat, numberOfEntries) == null);
          HashMap.size(map)
        },
        M.equals(T.nat(numberOfEntries))
      ),
      test(
        "get",
        do {
          let map = empty<Nat, Text>();
          let random = Random(randomSeed);
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            ignore HashMap.insert(map, HashMap.nat, key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.get(map, HashMap.nat, key) == ?Nat.toText(key))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "update",
        do {
          let map = empty<Nat, Text>();
          let random = Random(randomSeed);
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            ignore HashMap.insert(map, HashMap.nat, key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.containsKey(map, HashMap.nat, key));
            let oldValue = HashMap.insert(map, HashMap.nat, key, Nat.toText(key) # "!");
            assert (oldValue != null)
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.containsKey(map, HashMap.nat, key));
            assert (HashMap.get(map, HashMap.nat, key) == ?(Nat.toText(key) # "!"))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "remove",
        do {
          let map = empty<Nat, Text>();
          let random = Random(randomSeed);
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            ignore HashMap.insert(map, HashMap.nat, key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.containsKey(map, HashMap.nat, key));
            assert (HashMap.get(map, HashMap.nat, key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (HashMap.containsKey(map, HashMap.nat, key)) {
              ignore HashMap.remove(map, HashMap.nat, key);
              assert (not HashMap.containsKey(map, HashMap.nat, key))
            } else {
              ignore HashMap.remove(map, HashMap.nat, key)
            };
            assert (HashMap.get(map, HashMap.nat, key) == null)
          };
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      test(
        "remove",
        do {
          let map = empty<Nat, Text>();
          let random = Random(randomSeed);
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            ignore HashMap.insert(map, HashMap.nat, key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.containsKey(map, HashMap.nat, key));
            assert (HashMap.get(map, HashMap.nat, key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (HashMap.containsKey(map, HashMap.nat, key)) {
              assert HashMap.remove(map, HashMap.nat, key) != null;
              assert (not HashMap.containsKey(map, HashMap.nat, key))
            } else {
              assert HashMap.remove(map, HashMap.nat, key) == null
            };
            assert (HashMap.get(map, HashMap.nat, key) == null)
          };
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      test(
        "take",
        do {
          let map = empty<Nat, Text>();
          let random = Random(randomSeed);
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            ignore HashMap.insert(map, HashMap.nat, key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (HashMap.containsKey(map, HashMap.nat, key));
            assert (HashMap.get(map, HashMap.nat, key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (HashMap.containsKey(map, HashMap.nat, key)) {
              assert HashMap.remove(map, HashMap.nat, key) == ?(Nat.toText(key));
              assert (not HashMap.containsKey(map, HashMap.nat, key))
            } else {
              assert HashMap.remove(map, HashMap.nat, key) == null
            };
            assert (HashMap.get(map, HashMap.nat, key) == null)
          };
          HashMap.size(map)
        },
        M.equals(T.nat(0))
      ),
      test(
        "iterate",
        do {
          let map = empty<Nat, Text>();
          for (index in Nat.range(0, numberOfEntries)) {
            ignore HashMap.insert(map, HashMap.nat, index, Nat.toText(index))
          };
          var index = 0;
          for ((key, value) in sortedEntries(map).values()) {
            assert (key == index);
            assert (value == Nat.toText(index));
            index += 1
          };
          index
        },
        M.equals(T.nat(numberOfEntries))
      ),
    ]
  )
);

run(
  suite(
    "add, update, put",
    [
      test(
        "add disjoint",
        do {
          let map = empty<Nat, Text>();
          ignore HashMap.insert(map, HashMap.nat, 0, "0");
          ignore HashMap.insert(map, HashMap.nat, 1, "1");
          HashMap.size(map)
        },
        M.equals(T.nat(2))
      ),
      test(
        "put existing",
        do {
          let map = empty<Nat, Text>();
          ignore HashMap.insert(map, HashMap.nat, 0, "0");
          ignore HashMap.insert(map, HashMap.nat, 0, "Zero");
          HashMap.get(map, HashMap.nat, 0)
        },
        M.equals(T.optional(T.textTestable, ?"Zero"))
      )
    ]
  )
);
