# Periodic Tasks -benchmark

## Run in simulator (Verilator)

From project root (.../Atalanta):

```sh
# Run the non-PCS version
make verilate simv RUST=1 TEST_DIR=examples/periodic_tasks TEST=periodic_tasks

# Run the PCS version
make verilate simv RUST=1 TEST_DIR=examples/periodic_tasks TEST=periodic_tasks CARGO_FLAGS="-Fpcs"

# Run the PCS version with inlined ISRs
make verilate simv RUST=1 TEST_DIR=examples/periodic_tasks TEST=periodic_tasks CARGO_FLAGS="-Fpcs -Finline-isrs"
```

## Run on FPGA

From project directory (.../periodic_tasks):

```sh
# Non-PCS
cargo run --release -Ffpga

# PCS
cargo run --release -Ffpga -Fpcs

# PCS with inlined ISRs
cargo run --release -Ffpga -Fpcs -Finline-isrs
```
