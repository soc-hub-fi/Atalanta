# Priority Queue -benchmark

## Run in simulator (Verilator)

From project root (.../Atalanta):

```sh
# Run with software priority queue
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench

# Run with non-virtualized HW priority queue
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench CARGO_FLAGS="-Fuse-hwq"

# Run with virtualized HW priority queue
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench CARGO_FLAGS="-Fuse-hwq -Fvirtq"
```

## Run on FPGA

From project directory (.../pqbench):

```sh
# Run with software priority queue
cargo run --release -Ffpga

# Run with non-virtualized HW priority queue
cargo run --release -Ffpga -Fuse-hwq

# Run with virtualized HW priority queue
cargo run --release -Ffpga -Fuse-hwq -Fvirtq
```

## Special builds

Run on RV32IMC (sim or FPGA):

```sh
# Simulator (from project root .../Atalanta)
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqprof TARGET="riscv32imc-unknown-none-elf"

# FPGA (from project directory .../pqbench)
cargo run -Ffpga --target riscv32imc-unknown-none-elf

# Emit ASM for simulator build of pqprof
cargo rustc --release --example pqprof -Frtl-tb --target riscv32imc-unknown-none-elf -Fuse-hwq -Fvirtq -- --emit asm
```
