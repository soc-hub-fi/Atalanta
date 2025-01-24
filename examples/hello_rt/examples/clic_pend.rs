//! Tests that the CLIC HAL works as expected by raising an interrupt.
#![no_main]
#![no_std]

use bsp::{
    clic::{Clic, InterruptNumber},
    interrupt::Interrupt,
    riscv,
    rt::entry,
    sprintln, tb,
    uart::ApbUart,
};
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

const IRQ: Interrupt = Interrupt::MachineSoft;

static mut LAST_IRQ: Option<u16> = None;

/// Example entry point
#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(bsp::CPU_FREQ, UART_BAUD);
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

        tb::signal_pass(Some(&mut serial))
    }
    // If execution gets here in spite of pending the IRQ, we have failed
    else {
        tear_irq(IRQ);
        tb::signal_fail(Some(&mut serial))
    }
    loop {}
}

#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    assert!(irq_code == IRQ.number());

    // Save the IRQ code for validation in mains
    unsafe { LAST_IRQ = Some(irq_code) };
}
