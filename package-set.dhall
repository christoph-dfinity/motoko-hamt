let upstream =
      https://github.com/dfinity/vessel-package-set/releases/download/mo-0.14.14-20250701/package-set.dhall sha256:7c056ddd3ee425ba36b683fec8287c210d70d483f8ceba5cc89fd4f0646b3c69
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "siphash"
      , version = "1.0.3"
      , repo = "https://github.com/christoph-dfinity/motoko-siphash"
      , dependencies = ["core"] : List Text
      },
      { name = "bench"
      , version = "5660e2b17b941265b213d6cb0c49956c3a74e3cb"
      , repo = "https://github.com/caffeinelabs/mops-bench"
      , dependencies = ["core"] : List Text
      },
      { name = "test"
      , version = "06d7c77accb9fb08830643aa8f0e346295f6b263"
      , repo = "https://github.com/caffeinelabs/mops-test"
      , dependencies = ["core"] : List Text
      },
      { name = "hashmap"
      , version = "94d509f97d70ac03828eee3064d939a3259eab78"
      , repo = "https://github.com/ZhenyaUsenko/motoko-hash-map"
      , dependencies = [] : List Text
      },
      { name = "core"
      , version = "v2.3.1"
      , repo = "https://github.com/dfinity/motoko-core"
      , dependencies = [] : List Text
      },
    ] : List Package

in  upstream # additions
