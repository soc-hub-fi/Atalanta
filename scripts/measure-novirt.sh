#!/bin/bash

# Fail on error
set -e

# Check that everything compiles
cd examples/pqbench/
just check-novirt
cd -

# Run make verilate first to discard the majority of output
make verilate

mkdir -p logs

# -Fuse-bheap
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-bheap" | tee logs/bheap.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/bheap.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/bheap.log

# -Fuse-imap
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-imap" | tee logs/imap.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/imap.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/imap.log

# -Fuse-hwq
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-hwq" | tee logs/hwq.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/hwq.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a logs/hwq.log

