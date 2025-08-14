# PQPROF measurements

## 2025-08-11

### HW is RVI and SW is RVE, use-hwq (depth=8) + virtq

OUTDATED

| op | mcycle |
| :- | :-: |
| insert 0..8 | 119 |
| insert 8..16 | 289 once then 286 |

### HW is RVI and SW is RVI use-hwq (depth=8) + virtq

| op | mcycle |
| :- | :-: |
| insert 0..8 | 91 |
| insert 8..16 | 260 |
| drop 0..16 | 82 |

### HW is RVI and SW is RVI no feature flags, using BinaryHeap

| op | mcycle |
| :- | :-: |
| insert 0..16 | 145 once then 164 |
| drop 0..16 | 12639..11651 (~linear) |

Drop duration depends linearly on data-structure capacity.

size on disk 38k

### HW is RVI and SW is RVI use-imap (depth=128)

| op | mcycle |
| :- | :-: |
| insert 0..16 | 290 |
| drop 0..8 | 426 |
| drop 8..16 | 392 |

size on disk 39k

### HW is RVI and SW is RVI use-hwq (depth=256)

| op | mcycle |
| :- | :-: |
| insert 0..16 | 68 |
| drop 0..16 | 67 |

size on disk 31k
