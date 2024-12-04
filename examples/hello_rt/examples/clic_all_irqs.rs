//! Tests that all interrupts work as expected by raising them all, then
//! verifying this using the software dispatcher.
#![no_main]
#![no_std]

use core::ptr::{self, addr_of, addr_of_mut};

use bsp::{
    asm_delay,
    clic::{
        intattr::{Polarity, Trig},
        Clic, InterruptNumber, CLIC,
    },
    interrupt::Interrupt,
    print_example_name, riscv,
    rt::entry,
    sprintln, tb,
    uart::init_uart,
};
use hello_rt::UART_BAUD;

/// Interrupts under testing
const TEST_IRQS: &[Interrupt] = &[
    Interrupt::MachineSoft,
    Interrupt::MachineTimer,
    Interrupt::MachineExternal,
    Interrupt::Sixteen,
    Interrupt::Seventeen,
];

/// An array of 32 bits, one for each possible interrupt 0..32
static mut IRQ_RECVD: u32 = 0;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(bsp::CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    for &irq in TEST_IRQS {
        setup_irq(irq);
    }

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    // Raise each IRQ
    for &irq in TEST_IRQS {
        unsafe { CLIC::ip(irq).pend() };
    }

    // Busy wait for a while to make sure all interrupts have had time to be handled
    asm_delay(10_000);

    // Assert each interrupt was raised
    let mut failures = 0;
    for &irq in TEST_IRQS {
        let bit: u32 = 0b1 << irq.number();
        if unsafe { ptr::read_volatile(addr_of!(IRQ_RECVD) as *const _) & bit } == bit {
            tb::signal_partial_ok!("{:?} = {}", irq, irq.number());
        } else {
            tb::signal_partial_fail!("{:?} = {}", irq, irq.number());
            failures += 1;
        }
    }

    for &irq in TEST_IRQS {
        tear_irq(irq);
    }

    if failures == 0 {
        tb::signal_pass(true);
    } else {
        tb::signal_fail(true);
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

    // Record that the particular line was raised
    let mut val = unsafe { ptr::read_volatile(addr_of!(IRQ_RECVD) as *const _) };
    val |= 0b1u32 << irq_code;
    unsafe { ptr::write_volatile(addr_of_mut!(IRQ_RECVD) as *mut _, val) };
}
