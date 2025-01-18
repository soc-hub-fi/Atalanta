# Building Rust compiler from source

We need to build the Rust compiler from source to adequately support our build target. Fortunately
the right backends already exist in LLVM & Rust, so we only need to configure Rust correctly.

1. Assert that a 32-bit RISC-V toolchain is available on PATH
    - `which riscv32-unknown-elf-gcc`
2. Install build-time requirements (Ubuntu 24.04.1 LTS)
    - `sudo apt install cmake libssl-dev ninja-build pkg-config python3`
3. Clone Rust from source
    - `git clone --branch 1.84.0 --depth 1 https://github.com/rust-lang/rust rust-1.84.0`
4. Copy the compiler configuration file [`config.toml`](../podman/config.toml) from ../podman/config.toml to the root of the cloned Rust compiler
5. Build the compiler (may take minutes; get some coffee or tea)

    ```sh
    # Specify install location for the compiler. This can be anything you like.
    export DESTDIR="$HOME/.local/install/compilers/rust-1.84.0"

    # Build the compiler
    BOOTSTRAP_SKIP_TARGET_SANITY=1 ./x install compiler/rustc library/std
    ```

6. Link the installed compiler for rustup so that we can use it easily from anywhere on the system
    - `rustup toolchain link rve $DESTDIR/usr/local/`
