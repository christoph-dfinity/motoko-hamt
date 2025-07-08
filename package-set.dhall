let upstream =
      https://github.com/dfinity/vessel-package-set/releases/download/mo-0.14.14-20250701/package-set.dhall sha256:7c056ddd3ee425ba36b683fec8287c210d70d483f8ceba5cc89fd4f0646b3c69
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "siphash"
      , version = "bf65d05a084c23a8391b16efaf902b78918d00ad"
      , repo = "https://github.com/christoph-dfinity/motoko-siphash"
      , dependencies = ["base"] : List Text
      },
    ] : List Package

in  upstream # additions
