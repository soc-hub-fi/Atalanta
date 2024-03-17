//! Just an empty loop
#![no_main]
#![no_std]

// Make sure to link in runtime necessities
use rust_minimal as _;

/// Example entry point
#[no_mangle]
pub unsafe extern "C" fn entry() -> ! {
    loop {}
}
