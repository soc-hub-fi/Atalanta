//! This example demonstrates how the formatting facility sometimes fails to
//! output the correct value.
//!
//! The value of CLIC_BASE_ADDR should be 0x50000 but this gets printed as 0x50
#![no_main]
#![no_std]

use bsp::{mmap::CLIC_BASE_ADDR, rt::entry, sprintln, uart::init_uart};
use hello_rt::UART_BAUD;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(bsp::CPU_FREQ, UART_BAUD);

    let clic_base = CLIC_BASE_ADDR;

    // This should print 0x5_0000 but sometimes prints 0x50
    sprintln!("BASE: {:#x}", clic_base);

    #[allow(clippy::empty_loop)]
    loop {}
}
