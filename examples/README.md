# Software tests & examples

- `smoke_tests/` contains simple test cases verifying basic functionality of the Atalanta system
- `rust_minimal/` contains the bare minimum functional examples to run Rust on RT-Ibex
- `hello_rt/` contains a test suite built on top of `riscv-rt`, the open-source Rust runtime for
  RISC-V

## Smoke tests & C compilation

See the main [README.md](../README.md) at the root of the repository.

## Rust

### Requirements for compiling Rust

As of 2024-02-20, the RV32E base ISA is not supported by the Rust compiler. While it will catch up
eventually, for now we need to use our own toolchain.

You can pull the latest container with functioning setup using `podman` or `docker`. N.b., `podman`
& `docker` commands are interchangeable.

```sh
podman pull docker.io/heksaheksa/rust-rv32e:0.1-devel
```

See also the container sources at <https://github.com/soc-hub-fi/rust-rv32emc-docker> for further
advice on customization and `podman usage`, or read the Containerfile to understand how to configure
the toolchain locally.

Boot up the container and attach to it:

```sh
podman run --name rust-rv32e -dt rust-rv32e:0.1-devel
podman exec -it rust-rv32e /bin/bash
```

### Compiling Rust

Make sure you've some source code cloned up, and cd to the project directory (with a Cargo.toml file, e.g., `cd rust_minimal`)

Then, `cargo` works as usual:

```sh
# Compile all examples in release mode (small binaries, less debug utilities)
cargo build --release --examples

# Run an example on a connected FPGA, make sure you have an active OpenOCD connection or similar
cargo run --release --example led
```
