# PQPROF measurements

## N.b

TODO: optimize sw data structure. free_handles should possibly be a hashset instead of dequeue

## 2025-08-14, HW is RVI & SW is RVI

### use-bheap (depth=256)

| op | mcycle |
| :- | :-: |
| insert empty | 224 |
| insert 1..12 | 236, 258, 258, ... |
| drop 0..9 | 721--353 (~random variance) |
| drop 10 | 158 |
| drop 11 | 88 |
| dispatch 0..12 | 573 |

- Size on disk 47K

### use-imap (depth=256)

| op | mcycle |
| :- | :-: |
| insert empty | 194 |
| insert non-empty | 259 |
| drop 0 | 104 |
| drop 1..12 | 240--274 |
| dispatch | 575--814 |

- Insert empty should be same as bheap; something is slightly amiss
- Drop time has random variance.
- Dispatch time seems to scale linearly with element count.
- Size on disk 51K

### use-hwq (depth=256)

| op | mcycle |
| :- | :-: |
| insert 0..12 | 77 |
| drop 0..12 | 70 |
| dispatch | 123 |

size on disk 32K

### use-hwq (depth=8) + virtq (len=256)

OUTDATED

| op | mcycle |
| :- | :-: |
| insert 0..8 | 121 |
| insert 8..16 | 291 once then 288 |
| drop 0..16 | 86 |
| dispatch | 169 |

size on disk 53K
