default: test

check:
    $(vessel bin)/moc --check $(vessel sources) src/*.mo src/pure/*.mo test/*.mo

test:
  rm -rf Test.wasm
  $(vessel bin)/moc $(vessel sources) test/Test.mo -wasi-system-api
  wasmtime Test.wasm
