# Motoko HAMT

A stable HashMap for Motoko based on [Hash Array Mapped Tries].

Uses 64bit hashes as keys, and lists for conflicts in the leafs. Provides basically constant (log64) retrieval, insertion, removal.
While slower than a Hashtable in an amortized scenario the HAMT avoids linear re-hashing/resizing operations. This avoids
blowing past the instruction limit for single messages when maps grow large.

## Benchmarks

Run via `mops bench map`. Compares the performance of maps in core, base, and hamt, as well as the [most popular hash table](https://github.com/ZhenyaUsenko/motoko-hash-map) on Mops.

### Comparing Hash-based and Ordered Maps

Adds, retrieves, and deletes n map entries

### Instructions

|                   |     0 |       100 |       10000 |         500000 |
| :---------------- | ----: | --------: | ----------: | -------------: |
| hamt/HashMap      | 2_843 | 1_373_723 | 211_903_667 | 13_757_848_623 |
| core/Map          | 3_287 | 1_615_187 | 315_615_743 | 23_656_786_785 |
| mops/Hashtable    | 2_570 | 1_053_379 | 169_833_712 | 10_643_041_799 |
| hamt/pure/HashMap | 2_732 | 1_360_991 | 278_332_718 | 19_747_407_296 |
| core/pure/Map     | 2_638 | 1_123_594 | 233_978_304 | 17_400_556_567 |
| base/HashMap      | 3_180 | 3_899_020 | 467_588_323 | 25_059_203_769 |
| base/Trie         | 2_546 | 1_959_140 | 347_048_729 | 23_677_668_146 |

### Garbage Collection

|                   |     0 |        100 |     10000 |     500000 |
| :---------------- | ----: | ---------: | --------: | ---------: |
| hamt/HashMap      | 640 B |   60.3 KiB |  7.91 MiB | 490.68 MiB |
| core/Map          | 752 B |  24.89 KiB |  4.47 MiB | 369.27 MiB |
| mops/Hashtable    | 540 B |   22.8 KiB |  3.32 MiB | 201.19 MiB |
| hamt/pure/HashMap | 528 B |  58.42 KiB | 11.19 MiB | 792.81 MiB |
| core/pure/Map     | 528 B | 116.82 KiB | 21.76 MiB |   1.56 GiB |
| base/HashMap      | 864 B | 162.48 KiB | 16.99 MiB | 829.17 MiB |
| base/Trie         | 528 B | 105.22 KiB | 17.91 MiB |    1.2 GiB |

[Hash Array Mapped Tries]: https://infoscience.epfl.ch/server/api/core/bitstreams/f66a3023-2cd0-4b26-af6e-91a9a6ae7450/content
