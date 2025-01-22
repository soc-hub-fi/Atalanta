//! Blink GPIOs 0..=3

#![no_main]
#![no_std]

use core::{arch, mem};

use bsp::mmap::gpio::{RegisterBlock, GPIO_BASE};
use bsp::{mask_u32, rt::entry, uart::*, CPU_FREQ};
use bsp::{sprintln, write_u32, NOPS_PER_SEC};
use hello_rt::UART_BAUD;

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    sprintln!("[gpio_blink]");

    let gpio = GPIO_BASE as *mut RegisterBlock;

    unsafe {
        // Enable clocks for gpios 0..=3
        mask_u32(mem::transmute(&mut (*gpio).pads[0].en), 0xf);

        // Set gpios 0..=3 to output
        mask_u32(mem::transmute(&mut (*gpio).pads[0].dir), 0xf);
    }

    loop {
        unsafe {
            write_u32(mem::transmute(&mut (*gpio).pads[0].data_out), 0xf);

            for _ in 0..NOPS_PER_SEC / 2 {
                arch::asm!("nop");
            }

            write_u32(mem::transmute(&mut (*gpio).pads[0].data_out), 0x0);

            for _ in 0..NOPS_PER_SEC / 2 {
                arch::asm!("nop");
            }
        }
    }
}
