#!/bin/bash

# Fail on error
set -e

# -Fuse-bheap
cp logs/bheap.log logs/bheap-frozen.log

# -Fuse-imap
cp logs/imap.log logs/imap-frozen.log

# -Fuse-hwq
cp logs/hwq.log logs/hwq-frozen.log

# -Fuse-hwq -Fuse-virtq
cp logs/virtq.log logs/virtq-frozen.log

