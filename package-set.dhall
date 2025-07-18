let upstream =
      https://github.com/dfinity/vessel-package-set/releases/download/mo-0.14.14-20250701/package-set.dhall sha256:7c056ddd3ee425ba36b683fec8287c210d70d483f8ceba5cc89fd4f0646b3c69
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "siphash"
      , version = "1.0.0"
      , repo = "https://github.com/christoph-dfinity/motoko-siphash"
      , dependencies = ["base"] : List Text
      },
      { name = "bench"
      , version = "d4ce879cf251a27fa7167b523eee622baca42a53"
      , repo = "https://github.com/ZenVoich/bench"
      , dependencies = [] : List Text
      },
      { name = "test"
      , version = "e87a718eba50c0c5d2bd8b52320ed3c51f67e2cf"
      , repo = "https://github.com/ZenVoich/test"
      , dependencies = ["base"] : List Text
      },
      { name = "hashmap"
      , version = "94d509f97d70ac03828eee3064d939a3259eab78"
      , repo = "https://github.com/ZhenyaUsenko/motoko-hash-map"
      , dependencies = [] : List Text
      },
      { name = "core"
      , version = "preview-0.5.0"
      , repo = "https://github.com/dfinity/motoko-core"
      , dependencies = [] : List Text
      },
    ] : List Package

in  upstream # additions
