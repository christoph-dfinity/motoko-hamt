default: test

check: check-vessel

check-raw:
  .vessel/.bin/0.14.14/moc --check \
  --package base .vessel/base/bff049d57bc693b6f0098c7e0d848668c4a3bab2/src \
  --package bench .vessel/bench/d4ce879cf251a27fa7167b523eee622baca42a53/src \
  --package core .vessel/core/preview-0.5.0/src \
  --package hashmap .vessel/hashmap/94d509f97d70ac03828eee3064d939a3259eab78/src \
  --package matchers .vessel/matchers/3dac8a071b69e4e651b25a7d9683fe831eb7cffd/src \
  --package siphash .vessel/siphash/1.0.0/src \
  --package test .vessel/test/e87a718eba50c0c5d2bd8b52320ed3c51f67e2cf/src \
  src/*.mo src/pure/*.mo test/*.mo bench/*.mo

check-mops:
  $(mops toolchain bin moc) --check $(mops sources) src/*.mo src/pure/*.mo test/*.mo bench/*.mo

check-vessel:
  $(vessel bin)/moc --check $(vessel sources) src/*.mo src/pure/*.mo test/*.mo bench/*.mo

test:
  rm -rf Test.wasm
  $(vessel bin)/moc $(vessel sources) test/Test.mo -wasi-system-api
  wasmtime Test.wasm
