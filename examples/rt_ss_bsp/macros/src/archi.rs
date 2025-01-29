#[rustfmt::skip]
/// List of the register names to be stored in the trap frame
pub(crate) const TRAP_FRAME_RVE: &[&str] = &[
    // `ra`: return address, stores the address to return to after a function call or interrupt.
    "x1",
    // `t0`: temporary register `t0`, used for intermediate values
    "x5",
    // `t1`: temporary register `t1`, used for intermediate values
    "x6",
    // `t2`: temporary register `t2`, used for intermediate values
    "x7",
    // `a0`: argument register `a0`. Used to pass the first argument to a function.
    "x10",
    // `a1`: argument register `a1`. Used to pass the second argument to a function.
    "x11",
    // `a2`: argument register `a2`. Used to pass the third argument to a function.
    "x12",
    // `a3`: argument register `a3`. Used to pass the fourth argument to a function.
    "x13",
    // `a4`: argument register `a4`. Used to pass the fifth argument to a function.
    "x14",
    // `a5`: argument register `a5`. Used to pass the sixth argument to a function.
    "x15",
];

#[rustfmt::skip]
/// List of the register names to be stored in the trap frame
pub(crate) const TRAP_FRAME_RVI: &[&str] = &[
    "ra",
    "t0",
    "t1",
    "t2",
    "t3",
    "t4",
    "t5",
    "t6",
    "a0",
    "a1",
    "a2",
    "a3",
    "a4",
    "a5",
    "a6",
    "a7",
];

#[derive(Clone, Copy)]
pub(crate) enum RiscvArch {
    Rv32E,
    Rv32I,
}
