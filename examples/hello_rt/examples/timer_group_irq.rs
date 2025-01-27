//! Set up 4 timers to trigger one after each other. Assert that all interrupts
//! were fired.
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use bsp::{
    asm_delay,
    clic::Clic,
    riscv::{self, asm::wfi},
    rt::{entry, interrupt},
    sprint, sprintln,
    tb::signal_pass,
    timer_group::{Timer0, Timer1, Timer2, Timer3},
    uart::*,
    Interrupt, CPU_FREQ, NOPS_PER_SEC,
};
use hello_rt::{function, print_example_name, setup_irq, tear_irq, UART_BAUD};

/// Bit flag to store the interrupt IDs
static mut IRQ_RECVD: u64 = 0;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Timer0Cmp);
    setup_irq(Interrupt::Timer1Cmp);
    setup_irq(Interrupt::Timer2Cmp);
    setup_irq(Interrupt::Timer3Cmp);

    let mut timers = (
        Timer0::init(),
        Timer1::init(),
        Timer2::init(),
        Timer3::init(),
    );

    let interval = NOPS_PER_SEC / 2;
    timers.0.set_cmp(interval);
    timers.1.set_cmp(2 * interval);
    timers.2.set_cmp(3 * interval);
    timers.3.set_cmp(4 * interval);

    sprintln!("dispatching 4 timers");

    // Enable interrupts globally and dispatch all timers
    unsafe { riscv::interrupt::enable() };
    timers.0.enable();
    timers.1.enable();
    timers.2.enable();
    timers.3.enable();

    // HACK: timeout using asm delay, while mtimer is unstable
    asm_delay(5 * interval);

    // Tear down after timeout
    tear_irq(Interrupt::Timer0Cmp);
    tear_irq(Interrupt::Timer1Cmp);
    tear_irq(Interrupt::Timer2Cmp);
    tear_irq(Interrupt::Timer3Cmp);

    let all_flags = (0b1 << Interrupt::Timer0Cmp as u64)
        | (0b1 << Interrupt::Timer1Cmp as u64)
        | (0b1 << Interrupt::Timer2Cmp as u64)
        | (0b1 << Interrupt::Timer3Cmp as u64);
    // Safety: hopefully all interrupt handlers have already been run and there
    // isn't a race on IRQ_RECVD
    assert_eq!(all_flags, unsafe { IRQ_RECVD });

    signal_pass(Some(&mut serial));
    loop {
        // Wait for interrupt
        wfi();
    }
}

#[interrupt]
fn Timer0Cmp() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
    unsafe { Timer0::instance() }.disable();
}

#[interrupt]
fn Timer1Cmp() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
    unsafe { Timer1::instance() }.disable();
}

#[interrupt]
fn Timer2Cmp() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
    unsafe { Timer2::instance() }.disable();
}

#[interrupt]
fn Timer3Cmp() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
    unsafe { Timer3::instance() }.disable();
}
