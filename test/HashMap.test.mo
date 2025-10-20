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
import { type HashMap } "../src/HashMap";
import { type Seed; type HashFn; Nat = N } "../src/Types";

let { run; test; suite } = Suite;

let entryTestable = T.tuple2Testable(T.natTestable, T.textTestable);

func empty<K,V>() : HashMap<K, V> {
  HashMap.new((0, 0) : Seed)
};

func singleton<V>(key : Nat, v : V) : HashMap<Nat, V> {
  HashMap.singleton((0, 0) : Seed, key, v)
};

func sortedEntries<V>(map : HashMap<Nat, V>) : [(Nat, V)] {
  map.entries().toArray().sort(func (e1, e2) { Nat.compare(e1.0, e2.0) })
};

run(
  suite(
    "empty",
    [
      test(
        "size",
        empty<Nat, Text>().size(),
        M.equals(T.nat(0))
      ),
      test(
        "is empty",
        empty<Nat, Text>().isEmpty(),
        M.equals(T.bool(true))
      ),
      test(
        "add empty",
        do {
          let map = empty<Nat, Text>();
          ignore map.insert(0, "0");
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "insert empty",
        do {
          let map = empty<Nat, Text>();
          assert map.insert(0, "0").isNull();
          sortedEntries(map)
        },
        M.equals(T.array(entryTestable, [(0, "0")]))
      ),
      test(
        "remove empty",
        do {
          let map = empty<Nat, Text>();
          ignore map.remove(0);
          sortedEntries(map);
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove empty",
        do {
          let map = empty<Nat, Text>();
          assert map.remove(0).isNull();
          sortedEntries(map);
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "take absent",
        do {
          let map = empty<Nat, Text>();
          map.remove(0);
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "TODO: iterate forward",
        empty<Nat, Text>().entries().toArray(),
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "contains key",
        do {
          let map = empty<Nat, Text>();
          map.containsKey(0);
        },
        M.equals(T.bool(false))
      ),
      test(
        "get absent",
        do {
          let map = empty<Nat, Text>();
          map.get(0)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update absent",
        do {
          let map = empty<Nat, Text>();
          map.insert(0, "0")
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "clear",
        do {
          let map = empty<Nat, Text>();
          map.isEmpty();
        },
        M.equals(T.bool(true))
      ),
      test(
        "equal",
        do {
          let map1 = empty<Nat, Text>();
          let map2 = empty<Nat, Text>();
          map1.equal(map2);
        },
        M.equals(T.bool(true))
      ),
      test(
        "from iterator",
        do {
          let map = HashMap.fromIter<Nat, Text>(Iter.empty(), (0, 0) : Seed);
          map.size();
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
      //     assert (HashMap.compare(map1, map2, Text.compare) == #equal);
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
        singleton(0, "0").size(),
        M.equals(T.nat(1))
      ),
      test(
        "is empty",
        singleton(0, "0").isEmpty(),
        M.equals(T.bool(false))
      ),
      test(
        "add singleton old",
        do {
          let map = singleton<Text>(0, "0");
          ignore map.insert(0, "1");
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "1")]))
      ),
      test(
        "add singleton new",
        do {
          let map = singleton<Text>(0, "0");
          ignore map.insert(1, "1");
          // for (entry in Hamt.entries(map.hamt)) {
          //   Debug.print(debug_show entry)
          // };
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "0"), (1, "1")]))
      ),
      test(
        "insert singleton old",
        do {
          let map = singleton<Text>(0, "0");
          assert (map.insert(0, "1") == ?"0");
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "1")]))
      ),
      test(
        "insert singleton new",
        do {
          let map = singleton<Text>(0, "0");
          assert map.insert(1, "1") == null;
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "0"), (1, "1")]))
      ),
      test(
        "remove singleton old",
        do {
          let map = singleton<Text>(0, "0");
          ignore map.remove(0);
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove singleton new",
        do {
          let map = singleton<Text>(0, "0");
          ignore map.remove(1);
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "0")]))
      ),
      test(
        "remove singleton old",
        do {
          let map = singleton<Text>(0, "0");
          assert map.remove(0) != null;
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, []))
      ),
      test(
        "remove singleton new",
        do {
          let map = singleton<Text>(0, "0");
          assert map.remove(1) == null;
          sortedEntries(map)
        },
        M.equals(T.array<(Nat, Text)>(entryTestable, [(0, "0")]))
      ),
      test(
        "take function result",
        do {
          let map = singleton<Text>(0, "0");
          map.remove(0)
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "take map result",
        do {
          let map = singleton<Text>(0, "0");
          ignore map.remove(0);
          map.size()
        },
        M.equals(T.nat(0))
      ),
      test(
        "contains present key",
        do {
          let map = singleton<Text>(0, "0");
          map.containsKey(0)
        },
        M.equals(T.bool(true))
      ),
      test(
        "contains absent key",
        do {
          let map = singleton<Text>(0, "0");
          map.containsKey(1)
        },
        M.equals(T.bool(false))
      ),
      test(
        "get present",
        do {
          let map = singleton<Text>(0, "0");
          map.get(0)
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "get absent",
        do {
          let map = singleton<Text>(0, "0");
          map.get(1)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update present",
        do {
          let map = singleton<Text>(0, "0");
          map.insert(0, "Zero")
        },
        M.equals(T.optional(T.textTestable, ?"0"))
      ),
      test(
        "update absent",
        do {
          let map = singleton<Text>(0, "0");
          map.insert(1, "1")
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "replace if exists present",
        do {
          let map = singleton<Text>(0, "0");
          assert (map.insert(0, "Zero") == ?"0");
          map.size()
        },
        M.equals(T.nat(1))
      ),
      test(
        "remove",
        do {
          let map = singleton<Text>(0, "0");
          assert map.remove(0) == ?"0";
          map.size()
        },
        M.equals(T.nat(0))
      ),
      test(
        "equal",
        do {
          let map1 = singleton<Text>(0, "0");
          let map2 = singleton<Text>(0, "0");
          map1.equal(map2)
        },
        M.equals(T.bool(true))
      ),
      test(
        "not equal",
        do {
          let map1 = singleton<Text>(0, "0");
          let map2 = singleton<Text>(1, "1");
          map1.equal(map2)
        },
        M.equals(T.bool(false))
      ),
    ]
  )
);

let smallSize = 100;
func smallMap() : HashMap<Nat, Text> {
  let map = empty<Nat, Text>();
  for (index in Nat.range(0, smallSize)) {
    ignore map.insert(index, Nat.toText(index))
  };
  map
};

run(
  suite(
    "small map",
    [
      test(
        "size",
        smallMap().size(),
        M.equals(T.nat(smallSize))
      ),
      test(
        "is empty",
        smallMap().isEmpty(),
        M.equals(T.bool(false))
      ),
      test(
        "iterate forward",
        sortedEntries(smallMap()),
        M.equals(
          T.array<(Nat, Text)>(
            entryTestable,
            Array.tabulate<(Nat, Text)>(smallSize, func(index) { (index, Nat.toText(index)) })
          )
        )
      ),
      test(
        "contains absent key",
        do {
          let map = smallMap();
          map.containsKey(smallSize)
        },
        M.equals(T.bool(false))
      ),
      test(
        "get present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (map.get(index) == ?Nat.toText(index))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "get absent",
        do {
          let map = smallMap();
          map.get(smallSize)
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "update present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (map.insert(index, Nat.toText(index) # "!") == ?Nat.toText(index))
          };
          true
        },
        M.equals(T.bool(true))
      ),
      test(
        "update absent",
        do {
          let map = smallMap();
          map.insert(smallSize, Nat.toText(smallSize))
        },
        M.equals(T.optional(T.textTestable, null : ?Text))
      ),
      test(
        "replace if exists present",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert (map.insert(index, Nat.toText(index) # "!") == ?Nat.toText(index))
          };
          map.size()
        },
        M.equals(T.nat(smallSize))
      ),
      test(
        "remove",
        do {
          let map = smallMap();
          for (index in Nat.range(0, smallSize)) {
            assert map.remove(index) != null
          };
          map.isEmpty()
        },
        M.equals(T.bool(true))
      ),
      test(
        "equal",
        do {
          let map1 = smallMap();
          let map2 = smallMap();
          map1.equal(map2)
        },
        M.equals(T.bool(true))
      ),
      test(
        "not equal",
        do {
          let map1 = smallMap();
          let map2 = smallMap();
          assert map2.remove(smallSize - 1 : Nat) != null;
          map1.equal(map2)
        },
        M.equals(T.bool(false))
      ),
      test(
        "from iterator",
        do {
          let array = Array.tabulate<(Nat, Text)>(smallSize, func(index) { (index, Nat.toText(index)) });
          let map = HashMap.fromIter<Nat, Text>(array.values(), (0, 0) : Seed);
          for (index in Nat.range(0, smallSize)) {
            assert (map.get(index) == ?Nat.toText(index))
          };
          assert (map.equal(smallMap()));
          map.size()
        },
        M.equals(T.nat(smallSize))
      ),
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
            ignore map.insert(index, Nat.toText(index));
            assert (map.size() == index + 1);
            assert (map.get(index) == ?Nat.toText(index))
          };
          for (index in Nat.range(0, numberOfEntries)) {
            assert (map.get(index) == ?Nat.toText(index))
          };
          assert (map.get(numberOfEntries) == null);
          map.size()
        },
        M.equals(T.nat(numberOfEntries))
      ),
      test(
        "insert",
        do {
          let map = empty<Nat, Text>();
          for (index in Nat.range(0, numberOfEntries)) {
            assert map.insert(index, Nat.toText(index)) == null;
            assert (map.size() == index + 1);
            assert (map.get(index) == ?Nat.toText(index))
          };
          for (index in Nat.range(0, numberOfEntries)) {
            assert (map.insert(index, Nat.toText(index))) != null;
            assert (map.get(index) == ?Nat.toText(index))
          };
          assert (map.get(numberOfEntries) == null);
          map.size()
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
            ignore map.insert(key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.get(key) == ?Nat.toText(key))
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
            ignore map.insert(key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.containsKey(key));
            let oldValue = map.insert(key, Nat.toText(key) # "!");
            assert (oldValue != null)
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.containsKey(key));
            assert (map.get(key) == ?(Nat.toText(key) # "!"))
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
            ignore map.insert(key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.containsKey(key));
            assert (map.get(key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (map.containsKey(key)) {
              ignore map.remove(key);
              assert (not map.containsKey(key))
            } else {
              ignore map.remove(key)
            };
            assert (map.get(key) == null)
          };
          map.size()
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
            ignore map.insert(key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.containsKey(key));
            assert (map.get(key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (map.containsKey(key)) {
              assert map.remove(key) != null;
              assert (not map.containsKey(key))
            } else {
              assert map.remove(key) == null
            };
            assert (map.get(key) == null)
          };
          map.size()
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
            ignore map.insert(key, Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            assert (map.containsKey(key));
            assert (map.get(key) == ?Nat.toText(key))
          };
          random.reset();
          for (index in Nat.range(0, numberOfEntries)) {
            let key = random.next();
            if (map.containsKey(key)) {
              assert map.remove(key) == ?(Nat.toText(key));
              assert (not map.containsKey(key))
            } else {
              assert map.remove(key) == null
            };
            assert (map.get(key) == null)
          };
          map.size()
        },
        M.equals(T.nat(0))
      ),
      test(
        "iterate",
        do {
          let map = empty<Nat, Text>();
          for (index in Nat.range(0, numberOfEntries)) {
            ignore map.insert(index, Nat.toText(index))
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
          ignore map.insert(0, "0");
          ignore map.insert(1, "1");
          map.size()
        },
        M.equals(T.nat(2))
      ),
      test(
        "put existing",
        do {
          let map = empty<Nat, Text>();
          ignore map.insert(0, "0");
          ignore map.insert(0, "Zero");
          map.get(0)
        },
        M.equals(T.optional(T.textTestable, ?"Zero"))
      )
    ]
  )
);
