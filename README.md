# Motoko HAMT

An implementation of [Hash Array Mapped Tries] (HAMTs) in Motoko.

Uses 64bit hashes as keys, and linked lists for conflicts in the leafs.

## Benchmarks

Run via `mops bench map`. Compares the performance of core/Map, core/pure/Map, HAMT, as well as the [most popular hash table](https://github.com/ZhenyaUsenko/motoko-hash-map) on Mops.

Comparing Hash-based and Ordered Maps

Adds, retrieves, and deletes n map entries


## Instructions

|                   |     0 |       100 |       10000 |         500000 |
| :---------------- | ----: | --------: | ----------: | -------------: |
| hamt/HashMap      | 3_207 | 1_444_184 | 223_831_019 | 14_581_223_825 |
| core/Map          | 3_642 | 1_860_168 | 356_299_809 | 26_656_132_329 |
| mops/Hashtable    | 2_904 | 1_213_662 | 189_693_390 | 11_776_742_922 |
| hamt/pure/HashMap | 3_083 | 1_519_117 | 305_773_127 | 21_663_859_709 |
| core/pure/Map     | 2_976 | 1_311_807 | 268_446_651 | 19_906_471_429 |
| base/HashMap      | 3_541 | 4_182_989 | 500_269_756 | 26_873_255_625 |
| base/Trie         | 2_857 | 2_242_065 | 394_808_695 | 26_984_505_316 |


## Garbage Collection

|                   |     0 |        100 |     10000 |     500000 |
| :---------------- | ----: | ---------: | --------: | ---------: |
| hamt/HashMap      | 640 B |  61.37 KiB |  7.95 MiB | 492.59 MiB |
| core/Map          | 752 B |  25.16 KiB |  4.47 MiB | 369.27 MiB |
| mops/Hashtable    | 540 B |  22.95 KiB |  3.32 MiB | 201.19 MiB |
| hamt/pure/HashMap | 528 B |  57.63 KiB | 11.04 MiB | 785.18 MiB |
| core/pure/Map     | 528 B | 118.27 KiB | 21.76 MiB |   1.56 GiB |
| base/HashMap      | 864 B | 163.13 KiB | 16.99 MiB | 829.17 MiB |
| base/Trie         | 528 B | 106.89 KiB | 17.91 MiB |    1.2 GiB |


[Hash Array Mapped Tries]: https://infoscience.epfl.ch/server/api/core/bitstreams/f66a3023-2cd0-4b26-af6e-91a9a6ae7450/content
