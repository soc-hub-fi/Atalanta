# Rust RV32E container

Prior to November 2024, the RV32E base ISA was not supported by the Rust compiler. Compiler support has now caught up and an appropriate backend can be built from upstream sources.

However, we retain these instructions as legacy for situations where the upstream compiler cannot be used for one reason or another.

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

## Compiling Rust

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
