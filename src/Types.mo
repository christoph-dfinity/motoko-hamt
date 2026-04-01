import Nat64 "mo:core/Nat64";
import CorePrincipal "mo:core/Principal";
import Sip13 "mo:siphash/Sip13";

module {
  /// The provided hashing functions will use this seed to produce HashDoS resistant hashes.
  /// Needs to be sourced from secure randomness
  public type Seed = (Nat64, Nat64);

  public module Blob {
    public let hash = Sip13.hashBlob
  };

  public module Text {
    public let hash = Sip13.hashText
  };

  public module Nat {
    public let hash = Sip13.hashNat
  };

  public module Int {
    public let hash = Sip13.hashInt
  };

  public module Principal {
    public func hash(s : Seed, p : Principal) : Nat64 {
      Sip13.hashBlob(s, CorePrincipal.toBlob(p))
    };
  };
}
