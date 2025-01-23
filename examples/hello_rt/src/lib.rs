#![no_std]
#![no_main]

use bsp::{
    clic::{Clic, InterruptNumber, Polarity, Trig},
    sprintln, Interrupt,
};

pub mod clic;

pub const UART_BAUD: u32 = if cfg!(feature = "rtl-tb") {
    1_500_000
} else {
    9600
};

/// Setup `irq` for use with some basic defaults
///
/// Copy and customize this function if you need more involved configurations.
pub fn setup_irq(irq: Interrupt) {
    sprintln!("set up IRQ: {}", irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(0x88);
    unsafe { Clic::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
///
/// Copy and customize this function if you need more involved configurations.
pub fn tear_irq(irq: Interrupt) {
    sprintln!("tear down IRQ: {}", irq.number());
    Clic::ie(irq).disable();
    Clic::ctl(irq).set_level(0x0);
    Clic::attr(irq).set_shv(false);
    Clic::attr(irq).set_trig(Trig::Level);
    Clic::attr(irq).set_polarity(Polarity::Pos);
}
