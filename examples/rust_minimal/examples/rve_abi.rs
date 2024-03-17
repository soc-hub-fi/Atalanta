//! Stress register spilling
#![no_main]
#![no_std]

// Make sure to link in runtime necessities
use rust_minimal as _;

/// Example entry point
#[no_mangle]
pub unsafe extern "C" fn entry() -> ! {
    let res = many_args(1, 2, 3, 4, 5, 6, 7, 8);

    // avoid optimization
    assert!(res == 0);
    loop {}
}

#[inline(never)]
pub fn many_args(x1: u32, x2: u32, x3: u32, x4: u32, x5: u32, x6: u32, x7: u32, x8: u32) -> u32 {
    x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8
}
