import Nat64 "mo:core/Nat64";
import CorePrincipal "mo:core/Principal";
import Sip13 "mo:siphash/Sip13";

module {
  /// The provided hashing functions will use this seed to produce HashDoS resistant hashes.
  /// Needs to be sourced from secure randomness
  public type Seed = (Nat64, Nat64);

  /// Holds both a hash and equality function for the HashMap's key type
  public type HashFn<K> = (
    hash : (Seed, K) -> Nat64,
    eq : (K, K) -> Bool
  );

  public module Blob {
    /// A hashing function for Blob
    public let hashFn : HashFn<Blob> = (Sip13.hashBlob, func (x, y) = x == y);
  };

  public module Text {
    /// A hashing function for Text
    public let hashFn : HashFn<Text> = (Sip13.hashText, func (x, y) = x == y);
  };

  public module Nat {
    /// A hashing function for Nat
    public let hashFn : HashFn<Nat> = (Sip13.hashNat, func (x, y) = x == y);
  };

  public module Int {
    /// A hashing function for Int
    public let hashFn : HashFn<Int> = (Sip13.hashInt, func (x, y) = x == y);
  };

  public module Principal {
    /// A hashing function for Principals
    public let hashFn : HashFn<Principal> =
      (func (s, p) = Sip13.hashBlob(s, CorePrincipal.toBlob(p)), CorePrincipal.equal);
  };
}
