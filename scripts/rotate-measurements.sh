#!/bin/bash

# Fail on error
set -e

# -Fuse-bheap
cp logs/pqprof-bheap.log logs/pqprof-bheap-frozen.log

# -Fuse-imap
cp logs/pqprof-imap.log logs/pqprof-imap-frozen.log

# -Fuse-hwq
cp logs/pqprof-hwq.log logs/pqprof-hwq-frozen.log

# -Fuse-hwq -Fuse-virtq
cp logs/pqprof-virtq.log logs/pqprof-virtq-frozen.log

