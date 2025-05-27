# Motoko HAMT

An implementation of [Hash Array Mapped Tries] (HAMTs) in Motoko.

Uses 64bit hashes as keys, and linked lists for conflicts in the leafs.

## Benchmarks

Run via `mops bench`. Compares the performance of new-base/Map, new-base/pure/Map, HAMT, as well as the [most popular hash table](https://github.com/ZhenyaUsenko/motoko-hash-map) on Mops.

For the hash-based collections we also compare Sip13 (slow, but Hash-DOS resilient) and Fnv (fast-ish).

Adds, retrieves, and deletes n map entries

### Instructions

|                       |     0 |       100 |       10000 |         500000 |
| :-------------------- | ----: | --------: | ----------: | -------------: |
| OrderedMap            | 3_717 | 1_860_603 | 356_325_381 | 26_658_233_157 |
| HAMT - Sip            | 3_293 | 1_435_365 | 208_794_986 | 12_942_807_766 |
| HAMT - Fnv            | 3_288 |   957_344 | 152_721_661 |  9_818_717_434 |
| Hashtable - Sip       | 3_422 | 1_622_466 | 243_968_760 | 14_659_097_441 |
| Hashtable - Fnv       | 3_417 |   928_537 | 157_874_352 | 10_154_344_991 |
| pure/Map              | 2_879 | 1_311_710 | 268_447_058 | 19_907_977_455 |
| oldbase/HashMap - Sip | 4_021 | 4_484_291 | 578_411_341 | 31_523_278_772 |
| oldbase/Trie - Sip    | 3_366 | 2_582_997 | 434_985_708 | 29_341_522_939 |


### Garbage Collection

|                       |     0 |        100 |     10000 |     500000 |
| :-------------------- | ----: | ---------: | --------: | ---------: |
| OrderedMap            | 752 B |  25.16 KiB |  4.47 MiB | 369.27 MiB |
| HAMT - Sip            | 596 B |  78.54 KiB |  9.19 MiB |  523.9 MiB |
| HAMT - Fnv            | 596 B |  43.36 KiB |  5.19 MiB | 291.83 MiB |
| Hashtable - Sip       | 540 B |  71.87 KiB |   8.7 MiB |  487.5 MiB |
| Hashtable - Fnv       | 540 B |  13.66 KiB |  2.36 MiB |  157.9 MiB |
| pure/Map              | 528 B | 118.27 KiB | 21.76 MiB |   1.56 GiB |
| oldbase/HashMap - Sip | 864 B |  223.3 KiB | 24.72 MiB |   1.26 GiB |
| oldbase/Trie - Sip    | 544 B | 143.09 KiB | 21.79 MiB |   1.42 GiB |


[Hash Array Mapped Tries]: https://infoscience.epfl.ch/server/api/core/bitstreams/f66a3023-2cd0-4b26-af6e-91a9a6ae7450/content
