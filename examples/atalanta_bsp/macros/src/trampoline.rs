use crate::archi::CALLER_SAVE_EABI;
use crate::validate::validate_interrupt_handler;
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, ItemFn};

/// Generate a nesting trampoline for an interrupt handler
///
/// The function must have the signature `[unsafe] fn() [-> !]`.
///
/// N.b., this won't work with `export_name`.
pub(crate) fn nested_interrupt(args: TokenStream, input: TokenStream) -> TokenStream {
    let f = parse_macro_input!(input as ItemFn);

    if let Some(value) = validate_interrupt_handler(args.clone(), &f) {
        return value;
    }

    let ident = &f.sig.ident;
    let export_name = format!("{:#}", ident);
    let use_pcs = args.into_iter().any(|arg| arg.to_string() == "pcs");

    let start_trap = if use_pcs {
        start_pcs_trap(ident.to_string())
    } else {
        start_nested_interrupt_trap(ident)
    };

    quote!(
        #start_trap
        #[export_name = #export_name]
        #f
    )
    .into()
}

/// Generate the assembly instructions to store the trap frame
fn store_trap(frame: &[&str]) -> String {
    let (width, store) = (4, "sw");
    frame
        .iter()
        .enumerate()
        .map(|(i, reg)| format!("{store} {reg}, {i}*{width}(sp)"))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Generate the assembly instructions to load the trap frame
fn load_trap(frame: &[&str]) -> String {
    let (width, load) = (4, "lw");
    frame
        .iter()
        .enumerate()
        .map(|(i, reg)| format!("{load} {reg}, {i}*{width}(sp)"))
        .collect::<Vec<_>>()
        .join("\n")
}

const CALLER_SAVE_COUNT: usize = CALLER_SAVE_EABI.len();
const CAUSE_POS: usize = CALLER_SAVE_COUNT * 4;
const EPC_POS: usize = (CALLER_SAVE_COUNT + 1) * 4;

fn start_pcs_trap(interrupt: String) -> proc_macro2::TokenStream {
    let instructions = format!(
        r#"core::arch::global_asm!("
                .section .trap, \"ax\"
                .align 4
                .global _start_{interrupt}_trap
                _start_{interrupt}_trap:
                    #----- Interrupts disabled on entry ---#
                    csrsi mstatus, 8            // enable interrupts
                    #----- Interrupts enabled ---------#
                    la x10, {interrupt}         // load proper interrupt handler address into x10/a0 (x10/a0 is caller-save => saved by hardware in PCS mode)
                    jalr ra, x10, 0             // jump to corresponding interrupt handler proper (address stored in x10/a0)
                    csrci mstatus, 8            // disable interrupts
                    #----- Interrupts disabled  ---------#
                    mret                        // return from interrupt
                    ");"#
    );

    instructions.parse().unwrap()
}

fn start_nested_interrupt_trap(interrupt: &syn::Ident) -> proc_macro2::TokenStream {
    let interrupt = interrupt.to_string();
    let width = 4;
    let enter_save_count = CALLER_SAVE_EABI.len() + 2;
    let store_caller_save_regs = store_trap(CALLER_SAVE_EABI);

    let store_caller_save = format!(
        r#"
        addi sp, sp, -{enter_save_count} * {width}  // Create frame for caller save registers, mcause, and mepc
        {store_caller_save_regs}
        csrr x5, mcause                             // read cause into x5 / t0
        csrr x15, mepc                              // read epc into x15 / t1 / a5
        sw x5, {CAUSE_POS}(sp)                      // save cause / x5 / t0
        sw x15, {EPC_POS}(sp)                       // save epc / x15 / t1 / a5
        "#
    );

    let instructions = format!(
        r#"core::arch::global_asm!("
                .section .trap, \"ax\"
                    .align 4
                    .global _start_{interrupt}_trap
                    _start_{interrupt}_trap:
                        #----- Interrupts disabled on entry ---#
                        {store_caller_save}
                        csrsi mstatus, 8          // enable interrupts
                        #----- Interrupts enabled ---------#
                        la a0, {interrupt}        // load proper interrupt handler address into a0
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
pub(crate) fn generate_continue_nested_trap() -> TokenStream {
    let width = 4;
    let load_caller_save_regs = load_trap(CALLER_SAVE_EABI);
    let exit_save_count = CALLER_SAVE_EABI.len() + 2;

    let load_exit_regs = format!(
        r#"
        lw x15, {EPC_POS}(sp)                       // restore epc from stack into x15 / t1 / a5
        lw x5, {CAUSE_POS}(sp)                      // restore cause from stack into x5 / t0
        csrw mepc, x15                              // put epc back into CSR
        csrw mcause, t0                             // put cause back into CSR
        {load_caller_save_regs}
        addi sp, sp, {exit_save_count} * {width}    // free stack frame
    "#
    );

    let instructions = format!(
        r#"
        core::arch::global_asm!("
            .section .trap, \"ax\"
            .align 4
            .global _continue_nested_trap
            _continue_nested_trap:
                jalr ra, a0, 0                              // jump to corresponding interrupt handler proper (address stored in a0)
                csrci mstatus, 8 # disable interrupts
                #----- Interrupts disabled  ---------#
                {load_exit_regs}
                mret                                        // return from interrupt
            ");"#
    );

    instructions.parse().unwrap()
}
