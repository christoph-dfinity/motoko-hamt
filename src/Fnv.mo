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
      hash ^= Nat64.fromNat32(Nat32.fromNat16(Nat16.fromNat8(blob[i])));
      hash *%= fnv_prime;
      i += 1;
    };
    hash;
  };
}
