use proc_macro::TokenStream;
use proc_macro2::Span;
use syn::{parse, spanned::Spanned, ItemFn, ReturnType, Type, Visibility};

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

    if !args.is_empty() {
        return Some(
            parse::Error::new(Span::call_site(), "This attribute accepts no arguments")
                .to_compile_error()
                .into(),
        );
    }
    None
}
