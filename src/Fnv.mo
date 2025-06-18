import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

module {
  public func hashNat32(nat : Nat32) : Nat32 {
    let fnv_prime : Nat32 = 16777619;
    var hash : Nat32 = 2166136261;
    hash ^= (nat & 0xFF) * fnv_prime;
    hash ^= ((nat >> 8) & 0xFF) * fnv_prime;
    hash ^= ((nat >> 16) & 0xFF) * fnv_prime;
    hash ^= ((nat >> 24) & 0xFF) * fnv_prime;
    hash
  };

  public func hash32(text : Text) : Nat32 {
    hash32Blob(Text.encodeUtf8(text));
  };

  public func hash32Blob(blob : Blob) : Nat32 {
    let fnv_prime : Nat32 = 16777619;
    var hash : Nat32 = 2166136261;
    let size = blob.size();
    var i = 0;
    while (i < size) {
      hash ^= Nat32.fromNat16(Nat16.fromNat8(blob[i]));
      hash *%= fnv_prime;
      i += 1;
    };
    hash
  };

  public func hash64(text : Text) : Nat64 {
    hash64Blob(Text.encodeUtf8(text));
  };

  public func hash64Blob(blob : Blob) : Nat64 {
    let fnv_prime : Nat64 = 1099511628211;
    var hash : Nat64 = 14695981039346656037;
    let size = blob.size();
    var i = 0;
    while (i < size) {
      hash ^= Nat64.fromNat(Nat8.toNat(blob[i]));
      hash *%= fnv_prime;
      i += 1;
    };
    hash;
  };

  public class FnvHasher() {
    let fnv_prime : Nat64 = 1099511628211;
    var hash : Nat64 = 14695981039346656037;

    public func writeNat8(x : Nat8) {
      var _hash : Nat64 = hash;
      _hash ^= Nat64.fromNat(Nat8.toNat(x));
      _hash *%= fnv_prime;
      hash := _hash;
    };

    public func writeNat16(x : Nat16) {
      let (b2, b1) = Nat16.explode(x);
      var _hash : Nat64 = hash;
      _hash ^= Nat64.fromNat(Nat8.toNat(b1));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b2));
      _hash *%= fnv_prime;
      hash := _hash;
    };

    public func writeNat32(x : Nat32) {
      let (b4, b3, b2, b1) = Nat32.explode(x);
      var _hash : Nat64 = hash;
      _hash ^= Nat64.fromNat(Nat8.toNat(b1));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b2));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b3));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b4));
      _hash *%= fnv_prime;
      hash := _hash;
    };

    public func writeNat64(x : Nat64) {
      let (b8, b7, b6, b5, b4, b3, b2, b1) = Nat64.explode(x);
      var _hash : Nat64 = hash;
      _hash ^= Nat64.fromNat(Nat8.toNat(b1));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b2));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b3));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b4));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b5));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b6));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b7));
      _hash *%= fnv_prime;
      _hash ^= Nat64.fromNat(Nat8.toNat(b8));
      _hash *%= fnv_prime;
      hash := _hash;
    };

    public func writeBytes(bytes : [Nat8]) {
      let size = bytes.size();
      var i = 0;
      var _hash : Nat64 = hash;
      while (i < size) {
        _hash ^= Nat64.fromNat(Nat8.toNat(bytes[i]));
        _hash *%= fnv_prime;
        i += 1;
      };
      hash := _hash;
    };

    public func writeBlob(bytes : Blob) {
      let size = bytes.size();
      var i = 0;
      var _hash : Nat64 = hash;
      while (i < size) {
        _hash ^= Nat64.fromNat(Nat8.toNat(bytes[i]));
        _hash *%= fnv_prime;
        i += 1;
      };
      hash := _hash;
    };

    public func reset() {
      hash := 14695981039346656037;
    };

    public func finish(): Nat64 {
      hash
    };
  };
};
