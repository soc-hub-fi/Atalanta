#[rustfmt::skip]
pub(crate) const CALLER_SAVE_EABI: &[&str] = &[
    // `ra`: return address, stores the address to return to after a function call or interrupt.
    "x1",
    // `t0`: temporary/link register
    "x5",
    // `a0`: Argument/return value
    "x10",
    // `a1`: Argument/return value
    "x11",
    // `a2`: Argument
    "x12",
    // `a3`: Argument
    "x13",
    // `t1`: Temporary (`a5` in RISC-V ABI)
    "x15",
];

// Kept for reference
#[allow(dead_code)]
#[rustfmt::skip]
pub(crate) const CALLEE_SAVE_EABI_RVE: &[&str] = &[
    // `sp`: stack pointer
    "x2",
    // `s3`: saved register (`t1` in RISC-V ABI)
    "x6",
    // `s4`: saved register (`t2` in RISC-V ABI)
    "x7",
    // `s0`/`fp`: saved register/frame pointer
    "x8",
    // `s1`: saved register
    "x9",
    // `s2`: saved register (`a4` in RISC-V ABI)
    "x14",
];

// Kept for reference
#[allow(dead_code)]
#[rustfmt::skip]
pub(crate) const CALLEE_SAVE_EABI_RVI: &[&str] = &[
    // `sp`: stack pointer
    "x2",
    // `s3`: saved register (`t1` in RISC-V ABI)
    "x6",
    // `s4`: saved register (`t2` in RISC-V ABI)
    "x7",
    // `s0`/`fp`: saved register/frame pointer
    "x8",
    // `s1`: saved register
    "x9",
    // `s2`: saved register (`a4` in RISC-V ABI)
    "x14",
    // `x16..=x31`: `s5-s20` saved registers (`a6-a7`, s2-s11`, `t3-t6` in RISC-V ABI)
    "x16", "x17", "x18", "x19", "x20", "x21", "x22", "x23",
    "x24", "x25", "x26", "x27", "x28", "x29", "x30", "x31",
];
