//! Tests that the mcause code is actually 1 for "IRQ", not 0 for "exception",
//! when an interrupt is fired.
//!
//! Note that this example will fail if compiled in debug mode. Reason is
//! unknown.
#![no_main]
#![no_std]

use bsp::{print_example_name, riscv, rt::entry, sprintln, tb, uart::init_uart};
use hello_rt::{clic::*, UART_BAUD};

// 3 == MSI
const IRQ_ID: u32 = 3;

static mut LAST_IRQ: Option<u32> = None;

/// Example entry point
#[entry]
fn main() -> ! {
    init_uart(bsp::CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    set_mnlbits(8);

    setup_irq(IRQ_ID);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    // Raise IRQ
    pend_int(IRQ_ID);

    if let Some(irq) = unsafe { LAST_IRQ } {
        assert!(IRQ_ID == irq);
        tear_irq(IRQ_ID);

        tb::signal_pass(true)
    }
    // If execution gets here in spite of pending the IRQ, we have failed
    else {
        tear_irq(IRQ_ID);
        tb::signal_fail(true)
    }
}

fn setup_irq(id: u32) {
    // Positive edge triggering
    set_trig(id, ClicTrig::Edge);
    enable_vectoring(id);
    set_level(id, 0x88);
    enable_int(id);
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
fn tear_irq(id: u32) {
    disable_int(id);
    disable_vectoring(id);
    set_trig(id, ClicTrig::Level);
}

// This function is run if `mcause` MSB = 1 indicating an interrupt, otherwise
// the `ExceptionHandler` from lib.rs is run
#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    ack_int(IRQ_ID);

    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u32;
    assert!(irq_code == IRQ_ID);

    // Save the IRQ code for validation in mains
    unsafe { LAST_IRQ = Some(IRQ_ID) };
}
