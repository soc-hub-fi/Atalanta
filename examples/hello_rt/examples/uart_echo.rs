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

use bsp::{rt::entry, uart::*, CPU_FREQ};
use bsp::{sprint, sprintln};
use heapless::Vec;
use hello_rt::UART_BAUD;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    sprintln!("\r\n[uart_echo]");

    let mut buf = Vec::<u8, 16>::new();
    sprint!("Type something (enter to echo): ");
    loop {
        let byte = serial.getc();
        sprint!("{}", unsafe { core::str::from_utf8_unchecked(&[byte]) });
        // Safety: we check for buffer fullness every iteration
        unsafe { buf.push(byte).unwrap_unchecked() };
        if buf.is_full() || byte == b'\r' {
            sprintln!("\r\necho: {}", &unsafe {
                core::str::from_utf8_unchecked(&buf)
            });
            buf.clear();
            sprint!("Type something: ");
        }
    }
}
