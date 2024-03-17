//! Blink the led at an arbitrary frequency
#![no_main]
#![no_std]

use hello_rt::{asm_delay, led::*, NOPS_PER_SEC};
use riscv_rt::entry;

#[inline(never)]
fn blinky() {
    use Led::*;
    let ord = [Ld3, Ld0, Ld1, Ld2, Ld3].windows(2);
    let delay = NOPS_PER_SEC / ord.len() as u32;
    for leds in ord.cycle() {
        led_off(leds[0]);
        led_on(leds[1]);
        asm_delay(delay);
    }
}

#[entry]
fn main() -> ! {
    blinky();
    unreachable!()
}
