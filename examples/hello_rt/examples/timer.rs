//! Blinks fast for a second, then enters interrupt handler that sets the LED on
#![no_main]
#![no_std]

use core::ptr;

use hello_rt::{
    clic::*,
    irq::Irq,
    led::{led_off, led_on, led_toggle, Led},
    mmap::*,
    print_example_name, sprintln, tb,
    uart::init_uart,
    write_u32, CPU_FREQ,
};
use riscv_peripheral::clic::{
    intattr::{Polarity, Trig},
    InterruptNumber,
};
use riscv_rt::entry;

const MTIMER_IRQ: Irq = Irq::MachineTimer;

static mut LOCK: bool = true;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(hello_rt::CPU_FREQ, 9600);
    print_example_name!();

    // Set level bits to 8
    CLIC::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    setup_irq(MTIMER_IRQ);

    let prescaler = 0xf;

    // Set mtimecmp to something non-zero
    write_u32(MTIMECMP_LOW_ADDR, 2 * (CPU_FREQ / prescaler));

    // Enable timer [bit 0] & set prescaler [bits 20:8]
    write_u32(MTIME_CTRL_ADDR, prescaler << 8 | 0b1);

    use hello_rt::{asm_delay, led::Led::*, NOPS_PER_SEC};

    let ord = [Ld3, Ld2, Ld3].windows(2);
    let delay = NOPS_PER_SEC / ord.len() as u32;
    for leds in ord.cycle() {
        if !unsafe { ptr::read_volatile(ptr::addr_of_mut!(LOCK)) } {
            break;
        }
        led_off(leds[0]);
        led_on(leds[1]);
        asm_delay(delay);
    }

    // Disable timer [bit 0], prescaler 0xf00
    write_u32(MTIME_CTRL_ADDR, 0xf00);

    // No side-effects, reset to default state
    tear_irq(MTIMER_IRQ);

    tb::signal_ok(true)
}

#[export_name = "DefaultHandler"]
fn custom_interrupt_handler() {
    unsafe { CLIC::ip(MTIMER_IRQ).unpend() };

    // Flip a led and unlock the lock
    led_toggle(Led::Ld0);
    unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), false) };
}

fn setup_irq(irq: Irq) {
    sprintln!("set up IRQ: {}", irq.number());
    CLIC::attr(irq).set_trig(Trig::Edge);
    CLIC::attr(irq).set_polarity(Polarity::Pos);
    CLIC::attr(irq).set_shv(true);
    CLIC::ctl(irq).set_priority(0x88);
    unsafe { CLIC::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
#[inline]
fn tear_irq(irq: Irq) {
    sprintln!("tear down IRQ");
    CLIC::ie(irq).disable();
    CLIC::ctl(irq).set_priority(0x0);
    CLIC::attr(irq).set_shv(false);
    CLIC::attr(irq).set_trig(Trig::Level);
    CLIC::attr(irq).set_polarity(Polarity::Pos);
}
