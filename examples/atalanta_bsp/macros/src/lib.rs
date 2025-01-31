//! Proc-macros used by `atalanta_bsp`
mod archi;
mod trampoline;
mod validate;

use archi::RiscvArch;
use proc_macro::TokenStream;
use trampoline::{generate_continue_nested_trap, nested_interrupt};

// Sa. [crate::nested_interrupt]
// ???: making this into a doc comment causes ICE
#[proc_macro_attribute]
pub fn nested_interrupt_riscv32e(args: TokenStream, input: TokenStream) -> TokenStream {
    nested_interrupt(args, input)
}

// Sa. [crate::nested_interrupt]
// ???: making this into a doc comment causes ICE
#[proc_macro_attribute]
pub fn nested_interrupt_riscv32i(args: TokenStream, input: TokenStream) -> TokenStream {
    nested_interrupt(args, input)
}

#[proc_macro]
pub fn generate_continue_nested_trap_riscv32e(_input: TokenStream) -> TokenStream {
    const NO_HW_STACK: bool = false;
    generate_continue_nested_trap(RiscvArch::Rv32E, NO_HW_STACK)
}

#[proc_macro]
pub fn generate_continue_nested_trap_riscv32i(_input: TokenStream) -> TokenStream {
    const NO_HW_STACK: bool = false;
    generate_continue_nested_trap(RiscvArch::Rv32I, NO_HW_STACK)
}

#[proc_macro]
pub fn generate_continue_nested_pcs_trap_riscv32e(_input: TokenStream) -> TokenStream {
    const USE_HW_STACK: bool = true;
    generate_continue_nested_trap(RiscvArch::Rv32E, USE_HW_STACK)
}

#[proc_macro]
pub fn generate_continue_nested_pcs_trap_riscv32i(_input: TokenStream) -> TokenStream {
    const USE_HW_STACK: bool = true;
    generate_continue_nested_trap(RiscvArch::Rv32I, USE_HW_STACK)
}
