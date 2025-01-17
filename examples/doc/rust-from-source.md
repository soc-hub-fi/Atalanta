
# Building Rust compiler from source

We need to build the Rust compiler from source to adequately support our build target. Fortunately the right backends already exist in LLVM & Rust, so we only need to configure Rust correctly.

1. Install build-time requirements
    - `sudo apt install pkg-config cmake ninja-build libssl-dev`
2. Clone Rust from source
    - `git clone --branch 1.84.0 --depth 1 https://github.com/rust-lang/rust rust-1.84.0`
3. Configure the compiler
    - `./x setup`
    - Answer 'dist' when prompted, the rest of the settings don't matter.
4. Instruct the compiler to build our required targets by adding them to `config.toml`

    ```toml
    [build]
    target = [
        "x86_64-unknown-linux-gnu",
        "riscv32imc-unknown-none-elf",
        "riscv32e-unknown-none-elf",
        "riscv32ec-unknown-none-elf",
        "riscv32em-unknown-none-elf",
        "riscv32emc-unknown-none-elf",
    ]
    ```

5. Build the compiler (may take minutes; get some coffee or tea)

    ```sh
    # Specify install target location for the compiler.
    # This can be anything you like.
    export DESTDIR="$HOME/.local/install/  compilers/rust-1.84.0"

    # Build the compiler
    BOOTSTRAP_SKIP_TARGET_SANITY=1 ./x install -i compiler/rustc cargo rust-analyzer rustfmt src clippy
    ```

6. Link the installed compiler for rustup so that we can use it easily from anywhere on the system
    - `rustup toolchain link rve $DESTDIR/usr/local/`
