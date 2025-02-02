# Periodic Tasks -benchmark

## Run in simulator (Verilator)

From project root (.../Atalanta):

```sh
# Run the non-PCS version
make verilate simv RUST=1 TEST_DIR=examples/periodic_tasks TEST=periodic_tasks

# Run the PCS version
make verilate simv RUST=1 TEST_DIR=examples/periodic_tasks TEST=periodic_tasks CARGO_FLAGS="-Fpcs"
```

## Run on FPGA

```sh
# Non-PCS
cargo run --release -Ffpga

# PCS
cargo run --release -Ffpga -Fpcs
```
