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
LOG=logs/pqprof-bheap.log
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-bheap" | tee $LOG
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG

# -Fuse-imap
LOG=logs/pqprof-imap.log
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-imap" | tee $LOG
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG

# -Fuse-hwq
LOG=logs/pqprof-hwq.log
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-hwq" | tee $LOG
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof | tee -a $LOG

