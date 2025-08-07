use proc_macro::TokenStream;
use proc_macro2::Span;
use syn::{parse, spanned::Spanned, ItemFn, ReturnType, Type, Visibility};

/// List of platform interrupts. Should match with what's found in
/// [atalanta-bsp/src/interrupts.rs].
#[rustfmt::skip]
const INTERRUPTS: &[&str] = &[
    "MachineSoft", "MachineTimer", "MachineExternal",
    "Uart", "Gpio",
    "SpiRxTxIrq", "SpiEotIrq",
    "Timer0Ovf", "Timer0Cmp", "Timer1Ovf", "Timer1Cmp", "Timer2Ovf", "Timer2Cmp", "Timer3Ovf", "Timer3Cmp",
    "TqFull", "TqNotFull",
    "Nmi",
    "Dma0", "Dma1", "Dma2", "Dma3", "Dma4", "Dma5", "Dma6", "Dma7",
    "Dma8", "Dma9", "Dma10", "Dma11", "Dma12", "Dma13", "Dma14", "Dma15",
    "TqId0", "TqId1", "TqId2", "TqId3", "TqId4", "TqId5", "TqId6", "TqId7"
];

/// Returns possible errors with the interrupt handler definition
pub(crate) fn validate_interrupt_handler(args: TokenStream, f: &ItemFn) -> Option<TokenStream> {
    // check the function arguments
    if !f.sig.inputs.is_empty() {
        return Some(
            parse::Error::new(
                f.sig.inputs.first().unwrap().span(),
                "`#[nested_interrupt]` function should not have arguments",
            )
            .to_compile_error()
            .into(),
        );
    }

    // check that the supplied identified is one of known interrupt handlers
    let ident = &f.sig.ident;
    let export_name = format!("{:#}", ident);
    let valid_ident = INTERRUPTS.contains(&export_name.as_str());
    if !valid_ident {
        return Some(
            parse::Error::new(
                f.sig.ident.span(),
                "`#[nested_interrupt]` function must have identifier that matches with one of platform interrupts in atalanta_bsp::interrupt::Interrupt",
            )
            .to_compile_error()
            .into(),
        );
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
        return Some(
            parse::Error::new(
                f.span(),
                "`#[nested_interrupt]` function must have signature `[unsafe] fn() [-> !]`",
            )
            .to_compile_error()
            .into(),
        );
    }

    if !args.is_empty() && args.into_iter().next().unwrap().to_string() != "pcs" {
        return Some(
            parse::Error::new(
                Span::call_site(),
                "This attribute accepts no arguments other than 'pcs'",
            )
            .to_compile_error()
            .into(),
        );
    }

    None
}
