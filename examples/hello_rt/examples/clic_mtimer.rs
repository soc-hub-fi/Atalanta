//! Blinks fast for a second, then enters interrupt handler that sets the LED on
//!
//! # Known issues
//!
//! * Running this example twice without reset causes exception with
//!   * $mcause = 0x38000002
//!   * $mepc = 0x22
#![no_main]
#![no_std]

use core::ptr;

use bsp::{
    clic::{
        intattr::{Polarity, Trig},
        Clic, InterruptNumber,
    },
    interrupt::Interrupt,
    led::{led_off, led_on, led_toggle, Led},
    mmap::*,
    print_example_name, riscv,
    rt::entry,
    sprintln, tb,
    uart::init_uart,
    write_u32, CPU_FREQ,
};

const MTIMER_IRQ: Interrupt = Interrupt::MachineTimer;

static mut LOCK: bool = true;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(bsp::CPU_FREQ, 9600);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    setup_irq(MTIMER_IRQ);

    let prescaler = 0xf;

    // Set mtimecmp to something non-zero to produce a delayed interrupt
    write_u32(MTIMECMP_LOW_ADDR, 2 * (CPU_FREQ / prescaler));

    // Enable timer [bit 0] & set prescaler [bits 20:8]
    write_u32(MTIME_CTRL_ADDR, prescaler << 8 | 0b1);

    wait_on_lock();

    // No side-effects, reset to default state

    // Disable timer [bit 0], prescaler 0xf00
    write_u32(MTIME_CTRL_ADDR, 0xf00);
    write_u32(MTIMECMP_LOW_ADDR, 0);
    tear_irq(MTIMER_IRQ);
    riscv::interrupt::disable();

    tb::signal_pass(true)
}

fn wait_on_lock() {
    use bsp::{asm_delay, led::Led::*, NOPS_PER_SEC};

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
}

#[export_name = "DefaultHandler"]
fn custom_interrupt_handler() {
    unsafe { Clic::ip(MTIMER_IRQ).unpend() };

    // Flip a led and unlock the lock
    led_toggle(Led::Ld0);
    unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), false) };
}

fn setup_irq(irq: Interrupt) {
    sprintln!("set up IRQ {}", irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(0x88);
    unsafe { Clic::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
#[inline]
fn tear_irq(irq: Interrupt) {
    sprintln!("tear down IRQ {}", irq.number());
    Clic::ie(irq).disable();
    Clic::ctl(irq).set_level(0x0);
    Clic::attr(irq).set_shv(false);
    Clic::attr(irq).set_trig(Trig::Level);
    Clic::attr(irq).set_polarity(Polarity::Pos);
}
