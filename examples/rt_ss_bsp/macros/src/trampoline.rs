use crate::archi::{RiscvArch, TRAP_FRAME_RVE, TRAP_FRAME_RVI};
use crate::validate::validate_interrupt_handler;
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, ItemFn};

/// Generate a nesting trampoline for an interrupt handler
///
/// The function must have the signature `[unsafe] fn() [-> !]`.
///
/// N.b., this won't work with `export_name`.
pub(crate) fn nested_interrupt(
    args: TokenStream,
    input: TokenStream,
    arch: RiscvArch,
) -> TokenStream {
    let f = parse_macro_input!(input as ItemFn);

    if let Some(value) = validate_interrupt_handler(args, &f) {
        return value;
    }

    // XXX should we blacklist other attributes?
    let ident = &f.sig.ident;
    let export_name = format!("{:#}", ident);

    let start_trap = start_nested_interrupt_trap(ident, arch);

    quote!(
        #start_trap
        #[export_name = #export_name]
        #f
    )
    .into()
}

/// Generate the assembly instructions to store the trap frame.
///
/// The `filter` function is used to filter which registers to store.
/// This is useful to optimize the binary size in vectored interrupt mode, which
/// divides the trap frame storage in two parts: the first part saves space in
/// the stack and stores only the `a0` register, while the second part stores
/// the remaining registers.
fn store_trap<T: FnMut(&str) -> bool>(arch: RiscvArch, mut filter: T) -> String {
    let (width, store) = (4, "sw");
    let trap_frame = match arch {
        RiscvArch::Rv32E => TRAP_FRAME_RVE,
        RiscvArch::Rv32I => TRAP_FRAME_RVI,
    };
    trap_frame
        .iter()
        .enumerate()
        .filter(|(_, &reg)| filter(reg))
        .map(|(i, reg)| format!("{store} {reg}, {i}*{width}(sp)"))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Generate the assembly instructions to load the trap frame.
fn load_trap(arch: RiscvArch) -> String {
    let width = 4;
    let trap_frame = match arch {
        RiscvArch::Rv32E => TRAP_FRAME_RVE,
        RiscvArch::Rv32I => TRAP_FRAME_RVI,
    };
    trap_frame
        .iter()
        .enumerate()
        .map(|(i, reg)| format!("lw {reg}, {i}*{width}(sp)"))
        .collect::<Vec<_>>()
        .join("\n")
}

fn start_nested_interrupt_trap(ident: &syn::Ident, arch: RiscvArch) -> proc_macro2::TokenStream {
    let interrupt = ident.to_string();
    let width = 4;
    let trap_size = match arch {
        RiscvArch::Rv32E => TRAP_FRAME_RVE.len(),
        RiscvArch::Rv32I => TRAP_FRAME_RVI.len(),
    };
    let store_a0 = store_trap(arch, |r| r == "a0");

    let instructions = format!(
        r#"
core::arch::global_asm!(
    ".section .trap, \"ax\"
    .align 4
    .global _start_{interrupt}_trap
    _start_{interrupt}_trap:
        #----- Interrupts disabled on entry ---#
        addi sp, sp, -4 * {width}   # Create frame for t0, t1, mcause, mepc
        sw t0, 0(sp)     # save t0
        csrr t0, mcause  # read cause
        sw t1, 4(sp)     # save t1
        csrr t1, mepc    # read epc
        sw t0, 8(sp)     # save cause
        sw t1, 12(sp)    # save epc
        csrsi mstatus, 8 # enable interrupts
        #----- Interrupts enabled ---------#
        addi sp, sp, -{trap_size} * {width} // allocate space for trap frame
        {store_a0}                          // store trap partially (only register a0)
        la a0, {interrupt}                  // load interrupt handler address into a0
        j _continue_nested_trap   // jump to common part of interrupt trap
");"#
    );

    instructions.parse().unwrap()
}

/// Generates a shared '_continue_nested_trap' routine in assembly
///
/// The '_continue_nested_trap' function stores the trap frame partially (all
/// registers except a0), jumps to the interrupt handler, and restores the trap
/// frame.
pub(crate) fn generate_continue_nested_trap(arch: RiscvArch) -> TokenStream {
    let width = 4;
    let trap_size = match arch {
        RiscvArch::Rv32E => TRAP_FRAME_RVE.len(),
        RiscvArch::Rv32I => TRAP_FRAME_RVI.len(),
    };
    let store_continue = store_trap(arch, |reg| reg != "a0");
    let load = load_trap(arch);

    let instructions = format!(
        r#"
core::arch::global_asm!(
".section .trap, \"ax\"

.align 4
.global _continue_nested_trap
_continue_nested_trap:
    {store_continue}                   // store trap partially (all registers except a0)
    jalr ra, a0, 0                     // jump to corresponding interrupt handler (address stored in a0)
    {load}                             // restore trap frame
    addi sp, sp, {trap_size} * {width} // deallocate space for trap frame
    lw t1, 12(sp)    # restore epc
    lw t0, 8(sp)     # restore cause
    csrci mstatus, 8 # disable interrupts
    #----- Interrupts disabled  ---------#
    csrw mepc, t1    # put epc back
    lw t1, 4(sp)     # restore t1
    csrw mcause, t0  # put cause back
    lw t0, 0(sp)     # restore t0
    addi sp, sp, 4 * {width} # free stack frame
    mret                              // return from interrupt
");"#
    );

    instructions.parse().unwrap()
}
