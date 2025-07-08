let upstream =
      https://github.com/dfinity/vessel-package-set/releases/download/mo-0.14.10-20250513/package-set.dhall sha256:dba0f33dc857da6fe1cdcad2d165af7b6e3d106f70717b6ff3f54bf08d0dc22d
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
