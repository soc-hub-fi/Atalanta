# Software tests & examples

- `smoke_tests/` contains simple test cases verifying basic functionality of the Atalanta system
- `rust_minimal/` contains the bare minimum, dependency-free functional examples to run Rust on
  RT-Ibex
- `hello_rt/` contains a test suite built on top of `riscv-rt`, the open-source Rust runtime for
  RISC-V

## Smoke tests & C compilation

See the main [README.md](../README.md) at the root of the repository.

## Rust

### Requirements for compiling Rust

- Install [rustup](https://rustup.rs) the Rust toolchain manager
- A [RISC-V compiler](https://github.com/riscv-collab/riscv-gnu-toolchain)

Then, you'll just need a compiler with a RV32E backend. Currently, there are two options:

1. [Install Rust from source](./doc/rust-from-source.md) (recommended)
2. [Install a container with RVE support](./doc/rust-rv32e-container.md)

### Compiling Rust

- Compile all available examples

    ```sh
    cd hello_rt
    # Hello RT must be compiled with either -Ffpga or -Frtl-tb based on target platform
    cargo build --examples -Ffpga
    ```

### VS Code settings for Rust

Adjust your settings at the workspace root (".../Atalanta"):

```json
// .vscode/settings.json
{
    "rust-analyzer.linkedProjects": [
        "examples/hello_rt/Cargo.toml",
        "examples/periodic_tasks/Cargo.toml"
    ],
    "rust-analyzer.cargo.features": [
        // crates must be compiled with either `fpga` or `rtl-tb` depending on target platform
        "fpga",
    ],
    "rust-analyzer.cargo.target": "riscv32emc-unknown-none-elf",
    // check.allTargets & cargo.extraArgs helps us avoid the superfluous error on "can't find crate
    // for `test`"
    "rust-analyzer.check.allTargets": false,
    "rust-analyzer.cargo.extraArgs": [
        "--examples"
    ]
}
```

Additionally, we recommend you turn off `tamasfe.even-better-toml` extension for VS Code which
creates a false positive on our custom RVE toolchain configuration in "rust-toolchain.toml".

### FPGA verification flight check for Rust

1. Flash bitstream onto board
2. Connect OpenOCD
3. Build examples
    - `cd hello_rt && cargo build --examples`
4. Run led blinker
    - `cargo run --example led`
5. Connect FTDI UART & check wiring (README.md)
6. Connect screen & run UART example
    - `screen /dev/ttyUSB* 9600`
    - `cargo run --example uart`
