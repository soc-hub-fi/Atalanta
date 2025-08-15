#!/bin/bash

# Fail on error
set -e

# -Fuse-bheap
mv logs/bheap.log logs/bheap-frozen.log

# -Fuse-imap
mv logs/imap.log logs/imap-frozen.log

# -Fuse-hwq
mv logs/hwq.log logs/hwq-frozen.log

mv logs/virtq.log logs/virtq-frozen.log

