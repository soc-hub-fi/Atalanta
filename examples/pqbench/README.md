# Priority Queue -benchmark

## Run in simulator (Verilator)

From project root (.../Atalanta):

```sh
# Run the non-PCS version
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench

# Run the PCS version
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench CARGO_FLAGS="-Fpcs"

# Run the PCS version with inlined ISRs
make verilate simv RUST=1 TEST_DIR=examples/pqbench TEST=pqbench CARGO_FLAGS="-Fpcs -Finline-isrs"
```

## Run on FPGA

From project directory (.../pqbench):

```sh
# Non-PCS
cargo run --release -Ffpga

# PCS
cargo run --release -Ffpga

# PCS with inlined ISRs
cargo run --release -Ffpga
```
