import Hamt "../src/Hamt";
import Iter "mo:core/Iter";
import M "mo:matchers/Matchers";
import Nat "mo:core/Nat";
import S "mo:matchers/Suite";
import Sip13 "mo:siphash/Sip13";
import T "mo:matchers/Testable";
import { type Hamt } "../src/Hamt";

module {
    func withDescription<A>(msg : Text, matcher : M.Matcher<A>) : M.Matcher<A> = {
      matches = func(item : A) : Bool = matcher.matches(item);
      describeMismatch = func(item : A, description : M.Description) {
        description.appendText(msg);
        matcher.describeMismatch(item, description);
      }
    };

  func natHash(n : Nat) : Nat64 {
    Sip13.hashNat((0 : Nat64, 0 : Nat64), n)
  };

  func hasEntry(k : Nat, v : Nat) : M.Matcher<Hamt<Nat>> {
    let eqVal : M.Matcher<?Nat> = M.equals(T.optional(T.natTestable, ?v));
    let matcher = M.contramap<?Nat, Hamt<Nat>>(eqVal, func map = Hamt.get(map, natHash(k)));
    withDescription("Entry at " # Nat.toText(k) # " failed with:\n  ", matcher)
  };

  public func suite() : S.Suite {
    S.suite("HAMT", [
      S.test("inserts values",
        do {
          let map = Hamt.singleton<Nat>(natHash(1), 2);
          ignore map.insert(natHash(2), 3);
          map
        },
        M.allOf([hasEntry(1, 2), hasEntry(2, 3)])
      ),
      S.test("0 - 9_999",
        do {
          let map : Hamt<Nat> = Hamt.new();
          for (i in Nat.range(0, 10_000)) {
            ignore map.insert(natHash(i), i);
          };
          map
        }, do {
          M.allOf(
            Iter.toArray(
              Iter.map(
                Nat.range(0, 10_000),
                func i = hasEntry(i, i)
              )
            )
          )
        }),
    ]);
  };
}
