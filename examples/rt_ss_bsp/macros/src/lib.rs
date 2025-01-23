//! Proc-macros used by `rt_ss_bsp`
use proc_macro::TokenStream;
use proc_macro2::Span;
use quote::quote;
use syn::{parse, parse_macro_input, spanned::Spanned, ItemFn, ReturnType, Type, Visibility};

#[rustfmt::skip]
/// List of the register names to be stored in the trap frame
const TRAP_FRAME_RVE: &[&str] = &[
    "ra",
    "t0",
    "t1",
    "t2",
    "a0",
    "a1",
    "a2",
    "a3",
    "a4",
    "a5",
];

#[rustfmt::skip]
/// List of the register names to be stored in the trap frame
const TRAP_FRAME_RVI: &[&str] = &[
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
enum RiscvArch {
    Rv32E,
    Rv32I,
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

#[proc_macro_attribute]
/// Attribute to declare an interrupt handler. The function must have the
/// signature `[unsafe] fn() [-> !]`. This macro generates the interrupt trap
/// handler in assembly for 32-bit RISC-V E targets.
///
/// Use
/// [riscv_rt::core_interrupt](https://docs.rs/riscv-rt/0.13.0/riscv_rt/attr.core_interrupt.html) or
/// [riscv_rt::external_interrupt](https://docs.rs/riscv-rt/0.13.0/riscv_rt/attr.external_interrupt.html)
/// instead if you don't need nesting.
///
/// N.b., this won't work with `export_name`.
pub fn nested_interrupt_riscv32e(args: TokenStream, input: TokenStream) -> TokenStream {
    nested_interrupt(args, input, RiscvArch::Rv32E)
}

#[proc_macro_attribute]
/// Attribute to declare an interrupt handler. The function must have the
/// signature `[unsafe] fn() [-> !]`. This macro generates the interrupt trap
/// handler in assembly for 32-bit RISC-V I targets.
///
/// Use
/// [riscv_rt::core_interrupt](https://docs.rs/riscv-rt/0.13.0/riscv_rt/attr.core_interrupt.html) or
/// [riscv_rt::external_interrupt](https://docs.rs/riscv-rt/0.13.0/riscv_rt/attr.external_interrupt.html)
/// instead if you don't need nesting.
///
/// N.b., this won't work with `export_name`.
pub fn nested_interrupt_riscv32i(args: TokenStream, input: TokenStream) -> TokenStream {
    nested_interrupt(args, input, RiscvArch::Rv32I)
}

fn nested_interrupt(args: TokenStream, input: TokenStream, arch: RiscvArch) -> TokenStream {
    let f = parse_macro_input!(input as ItemFn);

    // check the function arguments
    if !f.sig.inputs.is_empty() {
        return parse::Error::new(
            f.sig.inputs.first().unwrap().span(),
            "`#[nested_interrupt]` function should not have arguments",
        )
        .to_compile_error()
        .into();
    }

    // check the function signature
    let valid_signature = f.sig.constness.is_none()
        && f.sig.asyncness.is_none()
        && f.vis == Visibility::Inherited
        && f.sig.abi.is_none()
        && f.sig.generics.params.is_empty()
        && f.sig.generics.where_clause.is_none()
        && f.sig.variadic.is_none()
        && match f.sig.output {
            ReturnType::Default => true,
            ReturnType::Type(_, ref ty) => matches!(**ty, Type::Never(_)),
        };

    if !valid_signature {
        return parse::Error::new(
            f.span(),
            "`#[nested_interrupt]` function must have signature `[unsafe] fn() [-> !]`",
        )
        .to_compile_error()
        .into();
    }

    if !args.is_empty() {
        return parse::Error::new(Span::call_site(), "This attribute accepts no arguments")
            .to_compile_error()
            .into();
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

fn start_nested_interrupt_trap(ident: &syn::Ident, arch: RiscvArch) -> proc_macro2::TokenStream {
    let interrupt = ident.to_string();
    let width = 4;
    let trap_size = match arch {
        RiscvArch::Rv32E => TRAP_FRAME_RVE.len(),
        RiscvArch::Rv32I => TRAP_FRAME_RVI.len(),
    };
    let store = store_trap(arch, |r| r == "a0");

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
        {store}                             // store trap partially (only register a0)
        la a0, {interrupt}                  // load interrupt handler address into a0
        j _continue_interrupt_trap          // jump to common part of interrupt trap
");"#
    );

    instructions.parse().unwrap()
}

/// Generates vectored interrupt trap functions in assembly for RISCV-32E
/// targets.
#[proc_macro]
pub fn nested_vectored_interrupt_trap_riscv32e(_input: TokenStream) -> TokenStream {
    nested_vectored_interrupt_trap(RiscvArch::Rv32E)
}

/// Generates vectored interrupt trap functions in assembly for RISCV-32E
/// targets.
#[proc_macro]
pub fn nested_vectored_interrupt_trap_riscv32i(_input: TokenStream) -> TokenStream {
    nested_vectored_interrupt_trap(RiscvArch::Rv32I)
}

/// Generates global '_continue_interrupt_trap' function in assembly. The
/// '_continue_interrupt_trap' function stores the trap frame partially (all
/// registers except a0), jumps to the interrupt handler, and restores the trap
/// frame.
fn nested_vectored_interrupt_trap(arch: RiscvArch) -> TokenStream {
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
.global _continue_interrupt_trap
_continue_interrupt_trap:
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
