default: test

check: check-vessel

check-mops:
  $(mops toolchain bin moc) --check $(mops sources) src/*.mo src/pure/*.mo test/*.mo bench/*.mo

check-vessel:
  moc --check $(vessel sources) src/*.mo src/pure/*.mo test/*.mo bench/*.mo

test:
  rm -rf Test.wasm
  moc $(vessel sources) test/Test.mo -wasi-system-api
  wasmtime Test.wasm
