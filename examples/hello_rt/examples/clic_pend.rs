//! Tests that the CLIC HAL works as expected by raising an interrupt.
#![no_main]
#![no_std]

use bsp::{
    clic::{
        intattr::{Polarity, Trig},
        Clic, InterruptNumber,
    },
    interrupt::Interrupt,
    print_example_name, riscv,
    rt::entry,
    sprintln, tb,
    uart::init_uart,
};

const IRQ: Interrupt = Interrupt::MachineSoft;

static mut LAST_IRQ: Option<u16> = None;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(bsp::CPU_FREQ, 9600);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(IRQ);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    // Raise IRQ
    unsafe { Clic::ip(IRQ).pend() };

    if let Some(irq) = unsafe { LAST_IRQ } {
        sprintln!("IRQ handled: {}", IRQ.number());
        assert!(IRQ.number() == irq);
        tear_irq(IRQ);

        tb::signal_pass(true)
    }
    // If execution gets here in spite of pending the IRQ, we have failed
    else {
        tear_irq(IRQ);
        tb::signal_fail(true)
    }
}

fn setup_irq(irq: Interrupt) {
    sprintln!("set up IRQ: {}", irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(0x88);
    unsafe { Clic::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
fn tear_irq(irq: Interrupt) {
    sprintln!("tear down IRQ: {}", irq.number());
    Clic::ie(irq).disable();
    Clic::ctl(irq).set_level(0x0);
    Clic::attr(irq).set_shv(false);
    Clic::attr(irq).set_trig(Trig::Level);
    Clic::attr(irq).set_polarity(Polarity::Pos);
}

#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    assert!(irq_code == IRQ.number());

    // Save the IRQ code for validation in mains
    unsafe { LAST_IRQ = Some(irq_code) };
}
