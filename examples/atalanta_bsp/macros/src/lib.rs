//! Proc-macros used by `atalanta_bsp`
mod archi;
mod trampoline;
mod validate;

use proc_macro::TokenStream;
use syn::parse_macro_input;

/// Sa. [crate::trampoline::nested_interrupt]
#[proc_macro_attribute]
pub fn nested_interrupt_riscv32e(args: TokenStream, input: TokenStream) -> TokenStream {
    trampoline::nested_interrupt(args, input)
}

/// Sa. [crate::trampoline::nested_interrupt]
#[proc_macro_attribute]
pub fn nested_interrupt_riscv32i(args: TokenStream, input: TokenStream) -> TokenStream {
    trampoline::nested_interrupt(args, input)
}

/// Sa. [crate::trampoline::generate_continue_nested_trap_impl]
#[proc_macro]
pub fn generate_continue_nested_trap(_input: TokenStream) -> TokenStream {
    trampoline::generate_continue_nested_trap_impl()
}
