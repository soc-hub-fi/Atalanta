//! Proc-macros used by `atalanta_bsp`
mod archi;
mod trampoline;
mod validate;

use proc_macro::TokenStream;
use syn::parse_macro_input;

/// Sa. [crate::trampoline::nested_interrupt]
#[proc_macro_attribute]
pub fn nested_interrupt(args: TokenStream, input: TokenStream) -> TokenStream {
    trampoline::nested_interrupt(args, input)
}

/// Sa. [crate::trampoline::generate_pcs_trap_entry]
#[proc_macro]
pub fn generate_pcs_trap_entry(input: TokenStream) -> TokenStream {
    let interrupt = parse_macro_input!(input as syn::Ident);
    trampoline::generate_pcs_trap_entry(&interrupt.to_string()).into()
}

/// Sa. [crate::trampoline::generate_nested_trap_entry]
#[proc_macro]
pub fn generate_nested_trap_entry(input: TokenStream) -> TokenStream {
    let interrupt = parse_macro_input!(input as syn::Ident);
    trampoline::generate_nested_trap_entry(&interrupt.to_string()).into()
}

/// Sa. [crate::trampoline::generate_continue_nested_trap_impl]
#[proc_macro]
pub fn generate_continue_nested_trap(_input: TokenStream) -> TokenStream {
    trampoline::generate_continue_nested_trap_impl()
}
