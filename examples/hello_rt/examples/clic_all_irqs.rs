//! Tests that all interrupts work as expected by raising them all, then
//! verifying this using the software dispatcher.
#![no_main]
#![no_std]

use core::ptr::{self, addr_of, addr_of_mut};

use bsp::{
    asm_delay,
    clic::{Clic, InterruptNumber, CLIC},
    interrupt::Interrupt,
    print_example_name, riscv,
    rt::entry,
    sprintln, tb,
    uart::ApbUart,
};
use hello_rt::{setup_irq, tear_irq, UART_BAUD};

/// Interrupts under testing
const TEST_IRQS: &[Interrupt] = &[
    Interrupt::MachineSoft,
    Interrupt::MachineTimer,
    Interrupt::MachineExternal,
    Interrupt::Uart,
    // ???: enabling Nmi fails the test case
    //Interrupt::Nmi,
    Interrupt::Dma0,
    Interrupt::Dma1,
    Interrupt::Dma2,
    Interrupt::Dma3,
    Interrupt::Dma4,
    Interrupt::Dma5,
    Interrupt::Dma6,
    Interrupt::Dma7,
    Interrupt::Dma8,
    Interrupt::Dma9,
    Interrupt::Dma10,
    Interrupt::Dma11,
    Interrupt::Dma12,
    Interrupt::Dma13,
    Interrupt::Dma14,
    Interrupt::Dma15,
];

/// An array of 32 bits, one for each possible interrupt 0..32
static mut IRQ_RECVD: u64 = 0;

/// Example entry point
#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(bsp::CPU_FREQ, UART_BAUD);
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
        let bit: u64 = 0b1 << irq.number();
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
        tb::signal_pass(Some(&mut serial));
    } else {
        tb::signal_fail(Some(&mut serial));
    }
    loop {}
}

#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;

    // Record that the particular line was raised
    let mut val = unsafe { ptr::read_volatile(addr_of!(IRQ_RECVD) as *const _) };
    val |= 0b1u64 << irq_code;
    unsafe { ptr::write_volatile(addr_of_mut!(IRQ_RECVD) as *mut _, val) };
}
