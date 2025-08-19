#!/bin/bash

# Fail on error
set -e

# Check that everything compiles
cd examples/pqbench/
just check-virt
cd -

# Run make verilate first to discard the majority of output
make verilate

mkdir -p logs

# -Fuse-hwq -Fvirtq
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf" CARGO_FLAGS="-Fuse-hwq -Fvirtq" > logs/virtq.log
ls -lah examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/virtq.log
size -A -d examples/pqbench/target/riscv32imc-unknown-none-elf/release/examples/pqprof >> logs/virtq.log

