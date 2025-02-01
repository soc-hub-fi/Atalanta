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
