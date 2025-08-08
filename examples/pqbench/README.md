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
