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

As of 2024-04-30, the RV32E base ISA is not supported by the Rust compiler. While it will catch up
eventually, for now we need to use our own toolchain.

You can pull the latest container with functioning setup using `podman` or `docker`. N.b., `podman`
& `docker` commands are interchangeable.

```sh
podman pull docker.io/heksaheksa/rust-rv32e:0.2-devel
```

See also the container sources at <https://github.com/soc-hub-fi/rust-rv32emc-docker> for further
advice on how to use and customize the container, or read the Containerfile to understand how to
configure the toolchain locally for an improved user experience.

Boot up the container and attach to it:

```sh
podman run --name rust-rv32e -dt rust-rv32e:0.2-devel
podman exec -it rust-rv32e /bin/bash
```

### Compiling Rust

- Change directory to home
  - `cd`
- Copy your SSH keys to the container, e.g.,
  - `podman cp ~/.ssh/id_ed25519 rust-rv32e:/root/.ssh/id_ed25519`
- Clone the repository on the booted container / virtual machine, e.g.,
  - `git clone ssh://git@github.com/soc-hub-fi/Atalanta.git`
- Change to the project directory (with a Cargo.toml file), e.g.,
  - `cd Atalanta/examples/rust_minimal`

Then, `cargo` works as usual:

```sh
# Compile all examples in release mode (small binaries, less debug utilities)
cargo build --release --examples

# Run an example on a connected FPGA, make sure you have an active OpenOCD connection or similar
cargo run --release --example led
```

## VS Code settings for Rust

```json
{
    "rust-analyzer.linkedProjects": [
        "examples/rust_minimal/Cargo.toml",
        "examples/hello_rt/Cargo.toml"
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

## FPGA verification flight check for Rust

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
