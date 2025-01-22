//! Transmit text over UART
//!
//! UART pin map, incl. PYNQ-Z1:
//!
//! | Host  | Device    | PYNQ-Z1 |
//! | :-:   | :-:       | :-:     |
//! | TX    | RX        | IO12    |
//! | RX    | TX        | IO13    |
#![no_main]
#![no_std]

use bsp::mmap::LED_ADDR;
use bsp::{asm_delay, rt::entry, uart::*, write_u32, CPU_FREQ};
use hello_rt::UART_BAUD;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    serial.write_str("\r\n");
    serial.write_str("[UART] Hello from mock UART (Rust)!\r\n");
    serial.write_str("[UART] UART_TEST [PASSED]\r\n");

    // Write to the led address to signal test completion in CI
    write_u32(LED_ADDR, 0b1);

    loop {
        asm_delay(1_000_000);
        serial.write_str("[UART] tick\r\n");
    }
}
