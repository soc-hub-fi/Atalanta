//! Tests that the CLIC HAL works as expected by raising an interrupt.
#![no_main]
#![no_std]

use hello_rt::{
    clic::CLIC,
    irq::Irq,
    led::{led_on, Led},
    print_example_name, sprintln, tb,
    uart::init_uart,
};
use riscv_peripheral::clic::{
    intattr::{Polarity, Trig},
    InterruptNumber,
};
use riscv_rt::entry;

const IRQ: Irq = Irq::MachineSoft;

static mut LAST_IRQ: Option<u16> = None;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(hello_rt::CPU_FREQ, 9600);
    print_example_name!();

    // Set level bits to 8
    CLIC::smclicconfig().set_mnlbits(8);

    setup_irq(IRQ);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    // Raise IRQ
    unsafe { CLIC::ip(IRQ).pend() };

    if let Some(irq) = unsafe { LAST_IRQ } {
        sprintln!("IRQ handled: {}", IRQ.number());
        assert!(IRQ.number() == irq);
        tear_irq(IRQ);

        // Write to led address to signal test success in CI
        led_on(Led::Ld0);
        tb::signal_ok(true)
    }
    // If execution gets here in spite of pending the IRQ, we have failed
    else {
        tear_irq(IRQ);
        tb::signal_fail(true)
    }
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
fn tear_irq(irq: Irq) {
    sprintln!("tear down IRQ: {}", irq.number());
    CLIC::ie(irq).disable();
    CLIC::ctl(irq).set_priority(0x0);
    CLIC::attr(irq).set_shv(false);
    CLIC::attr(irq).set_trig(Trig::Level);
    CLIC::attr(irq).set_polarity(Polarity::Pos);
}

#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    unsafe { CLIC::ip(IRQ).unpend() };

    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    assert!(irq_code == IRQ.number());

    // Save the IRQ code for validation in mains
    unsafe { LAST_IRQ = Some(irq_code) };
}
