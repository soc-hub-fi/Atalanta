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

#[entry]
fn main() -> ! {
    init_uart(CPU_FREQ, 9600);

    uart_write("\r\n");
    uart_write("[UART] Hello from mock UART (Rust)!\r\n");
    uart_write("[UART] UART_TEST [PASSED]\r\n");

    // Write to the led address to signal test completion in CI
    write_u32(LED_ADDR, 0b1);

    loop {
        asm_delay(1_000_000);
        uart_write("[UART] tick\r\n");
    }
}
