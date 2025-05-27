# Motoko HAMT

An implementation of [Hash Array Mapped Tries] (HAMTs) in Motoko.

Uses 64bit hashes as keys, and linked lists for conflicts in the leafs.

## Benchmarks

Run via `mops bench`. Compares the performance of new-base/Map, new-base/pure/Map, HAMT, as well as the [most popular hash table](https://github.com/ZhenyaUsenko/motoko-hash-map) on Mops.

For the hash-based collections we also compare Sip13 (slow, but Hash-DOS resilient) and Fnv (fast-ish).

Adds, retrieves, and deletes n map entries

### Instructions

|                 |     0 |       100 |       10000 |         500000 |
| :-------------- | ----: | --------: | ----------: | -------------: |
| OrderedMap      | 3_446 | 1_860_332 | 356_324_606 | 26_658_226_586 |
| HAMT - Sip      | 3_053 | 1_448_392 | 210_115_822 | 13_008_908_256 |
| HAMT - Fnv      | 3_048 |   970_375 | 154_042_142 |  9_884_774_670 |
| Hashtable - Sip | 3_151 | 1_622_195 | 243_969_371 | 14_659_091_689 |
| Hashtable - Fnv | 3_148 |   928_268 | 157_874_083 | 10_154_343_903 |
| pure/Map        | 2_598 | 1_311_429 | 268_445_958 | 19_907_930_860 |


### Garbage Collection

|                 |     0 |        100 |     10000 |     500000 |
| :-------------- | ----: | ---------: | --------: | ---------: |
| OrderedMap      | 752 B |  25.16 KiB |  4.47 MiB | 369.27 MiB |
| HAMT - Sip      | 608 B |  80.12 KiB |  9.34 MiB | 531.53 MiB |
| HAMT - Fnv      | 608 B |  44.94 KiB |  5.35 MiB | 299.46 MiB |
| Hashtable - Sip | 540 B |  71.87 KiB |   8.7 MiB |  487.5 MiB |
| Hashtable - Fnv | 540 B |  13.66 KiB |  2.36 MiB |  157.9 MiB |
| pure/Map        | 528 B | 118.27 KiB | 21.76 MiB |   1.56 GiB |


[Hash Array Mapped Tries]: https://infoscience.epfl.ch/server/api/core/bitstreams/f66a3023-2cd0-4b26-af6e-91a9a6ae7450/content
