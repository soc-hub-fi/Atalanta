//! Simple program to read button value in polling loop and light up matching
//! LED on PYNQ-Z1 board.
#![no_main]
#![no_std]

use rust_minimal::{read_u32, write_u32};

const INPUT_ADDR: usize = 0x0003_0004;
const OUTPUT_ADDR: usize = 0x0003_0008;

#[inline(never)]
fn buttons() {
    loop {
        let in_vals = read_u32(INPUT_ADDR);
        write_u32(OUTPUT_ADDR, in_vals);
    }
}

/// Example entry point
#[no_mangle]
pub unsafe extern "C" fn entry() -> ! {
    buttons();
    loop {}
}
