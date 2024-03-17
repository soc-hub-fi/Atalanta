//! Blink the led at an arbitrary frequency
#![no_main]
#![no_std]

use rust_minimal::{asm_delay, write_u32, NOPS_PER_SEC};

const LED_ADDR: usize = 0x0003_0008;

#[inline(never)]
fn blinky() {
    loop {
        write_u32(LED_ADDR, 1);
        asm_delay(NOPS_PER_SEC / 2);
        write_u32(LED_ADDR, 0);
        asm_delay(NOPS_PER_SEC / 2);
    }
}

/// Example entry point
#[no_mangle]
pub unsafe extern "C" fn entry() -> ! {
    blinky();
    loop {}
}
