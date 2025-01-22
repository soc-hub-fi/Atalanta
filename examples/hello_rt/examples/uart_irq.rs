//! Reads bytes over UART using an interrupt
//!
//! Assumes test is run on hart 0 with no other cores interfering.
#![no_std]
#![no_main]
// SAFETY: this example does not provide any safety regarding peripheral sharing, and the correct
// implementation depends on the target platform.
#![allow(static_mut_refs)]

use core::sync::atomic::{AtomicBool, Ordering};

use bsp::{
    clic::Clic,
    riscv,
    rt::entry,
    sprintln,
    uart::{ApbUart, UartInterrupt},
    Interrupt, CPU_FREQ,
};
use hello_rt::{setup_irq, tear_irq, UART_BAUD};

static mut UART: Option<ApbUart> = None;
static mut RUNNING: AtomicBool = AtomicBool::new(true);

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    sprintln!("\r\n[uart_irq]");

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Uart);

    // Raise an interrupt when a byte is available
    serial.listen(UartInterrupt::OnData);

    // Share UART to the interrupt handler
    let _ = unsafe { UART.insert(serial) };

    unsafe {
        /*// Enable machine external interrupts (such as UART0)
        riscv::register::mie::set_mext();*/

        // Enable interrupts globally
        riscv::interrupt::enable();
    };

    sprintln!("Input a character to raise an interrupt ('q' to clean up & exit)");

    while unsafe { RUNNING.load(Ordering::Acquire) } {
        riscv::asm::wfi();
    }

    // Clean up
    tear_irq(Interrupt::Uart);
    riscv::interrupt::disable();

    loop {}
}

#[export_name = "DefaultHandler"]
fn receive_byte() {
    sprintln!("enter receive_byte");

    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!("code: {:#x}", irq_code);

    if let Some(uart) = unsafe { UART.as_mut() } {
        let ch = uart.getc() as char;
        sprintln!("byte: {}", ch);

        if ch == 'q' {
            unsafe { RUNNING.store(false, Ordering::Release) };
        }
    }
    sprintln!("exit receive_byte");
}
