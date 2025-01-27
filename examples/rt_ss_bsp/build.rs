use std::{collections::HashSet, env, fs, path::PathBuf};

const VALID_RISCV_EXTENSIONS: &[char] = &['i', 'e', 'm', 'c', 'a', 'f', 'd'];

fn add_linker_script() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    if cfg!(feature = "rt") {
        // Put the linker script somewhere the linker can find it.
        fs::write(out_dir.join("memory.x"), include_bytes!("memory.x")).unwrap();
        println!("cargo:rustc-link-search={}", out_dir.display());
        println!("cargo:rerun-if-changed=memory.x");
    }
}

/// Parse the target RISC-V architecture and returns its bit width and the
/// extension set
///
/// Returns a char set such as ['i', 'e'] based on which extensions are active
/// right now.
fn parse_extensions(target: &str, cargo_flags: &str) -> HashSet<char> {
    // isolate bit width and extensions from the rest of the target information
    let arch = target
        .trim_start_matches("riscv")
        .split('-')
        .next()
        .unwrap();

    let mut extensions: HashSet<char> = arch.chars().skip_while(|c| c.is_ascii_digit()).collect();
    // expand the 'g' shorthand extension
    if extensions.contains(&'g') {
        extensions.insert('i');
        extensions.insert('m');
        extensions.insert('a');
        extensions.insert('f');
        extensions.insert('d');
    }

    let cargo_flags = cargo_flags
        .split(0x1fu8 as char)
        .filter(|arg| !arg.is_empty());

    cargo_flags
        .filter(|k| k.starts_with("target-feature="))
        .flat_map(|str| {
            let flags = str.split('=').collect::<Vec<&str>>()[1];
            flags.split(',')
        })
        .for_each(|feature| {
            let chars = feature.chars().collect::<Vec<char>>();
            match chars[0] {
                '+' => {
                    extensions.insert(chars[1]);
                }
                '-' => {
                    extensions.remove(&chars[1]);
                }
                _ => {
                    panic!("Unsupported target feature operation");
                }
            }
        });

    extensions
}

fn main() {
    add_linker_script();

    let target = env::var("TARGET").unwrap();
    let cargo_flags = env::var("CARGO_ENCODED_RUSTFLAGS").unwrap();

    // Let cargo know we're using extension flags so it doesn't create a superfluous
    // warning about them
    for ext in VALID_RISCV_EXTENSIONS {
        println!("cargo::rustc-check-cfg=cfg(riscv{})", ext);
    }

    // Set configuration flags depending on the target
    if target.starts_with("riscv") {
        println!("cargo:rustc-cfg=riscv");
        // This is required until target_arch & target_feature risc-v work is
        // stable and in-use (rust 1.75.0)
        let extensions = parse_extensions(&target, &cargo_flags);

        // expose the ISA extensions
        for ext in &extensions {
            println!("cargo:rustc-cfg=riscv{}", ext);
        }
    }

    println!("cargo:rerun-if-changed=build.rs");
}
