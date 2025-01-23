//! Blink GPIOs 0..=3

#![no_main]
#![no_std]

use core::arch;

use bsp::gpio::GpioLo;
use bsp::{rt::entry, uart::*, CPU_FREQ};
use bsp::{sprintln, NOPS_PER_SEC};
use hello_rt::UART_BAUD;

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    sprintln!("[gpio_blink]");

    // Enable clocks and set as output for gpios 0..=3
    GpioLo::en(0xf);
    GpioLo::set_output(0xf);

    loop {
        unsafe {
            GpioLo::toggle(0xf);

            for _ in 0..NOPS_PER_SEC / 2 {
                arch::asm!("nop");
            }
        }
    }
}
