#!/bin/bash

# Fail on error
set -e

# Run make verilate first to discard the majority of output
make verilate

mkdir -p logs

# -Fuse-bheap
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-bheap" > logs/bheap.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/bheap.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/bheap.log

# -Fuse-imap
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-imap" > logs/imap.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/imap.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/imap.log

# -Fuse-hwq
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-hwq" > logs/hwq.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/hwq.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/hwq.log

