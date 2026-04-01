import Char "mo:core/Char";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Text "mo:core/Text";

module {
  public type Hash = Nat64;
  public type Bitmap = Nat64;

  let BITS_PER_LEVEL = 6;

  public func showBinary(x : Nat64) : Text {
    var n = x;
    var res = "";
    for (i in Nat.range(0, 64)) {
      if (i != 0 and i % BITS_PER_LEVEL == 0) res := "_" # res;
      if (n & 1 == 1) { res := "1" # res } else { res := "0" # res };
      n := n >> 1;
    };
    res;
  };

  public func showHex(x : Nat64) : Text {
    var n = x;
    var res = "";
    for (i in Nat.range(0, 8)) {
      let digit = n & 15;
      if (digit < 10) {
        res := Nat64.toText(digit) # res;
      } else {
        res := Text.fromChar(Char.fromNat32(Nat32.fromNat64(digit + 87))) # res;
      };
      n := n >> 4;
    };
    res;
  };

}
