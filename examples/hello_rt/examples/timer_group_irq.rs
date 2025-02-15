//! Set up 4 timers to trigger one after each other. Assert that all interrupts
//! were fired.
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use bsp::{
    clic::Clic,
    mmap::apb_timer::{TIMER0_ADDR, TIMER1_ADDR, TIMER2_ADDR, TIMER3_ADDR},
    mtimer::MTimer,
    riscv::{self, asm::wfi},
    rt::{entry, interrupt},
    sprint, sprintln,
    tb::signal_pass,
    timer_group::Timer,
    uart::*,
    Interrupt, CPU_FREQ, NOPS_PER_SEC,
};
use hello_rt::{function, print_example_name, setup_irq, tear_irq, UART_BAUD};

const INTERVAL: u32 = if cfg!(feature = "rtl-tb") {
    0x100
} else {
    // Just enough to be able to tell the timer's apart
    NOPS_PER_SEC / 2
};

/// Bit flag to store & verify the correct interrupt IDs fired
static mut IRQ_RECVD: u64 = 0;
static mut TIMEOUT: bool = false;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Setup 4 timers for verification and machine timer for timeout
    setup_irq(Interrupt::Timer0Cmp);
    setup_irq(Interrupt::Timer1Cmp);
    setup_irq(Interrupt::Timer2Cmp);
    setup_irq(Interrupt::Timer3Cmp);
    setup_irq(Interrupt::MachineTimer);

    // Use mtimer for timeout
    let mut mtimer = MTimer::instance();
    mtimer.set_cmp(5 * INTERVAL as u64);

    let mut timers = (
        Timer::init::<TIMER0_ADDR>(),
        Timer::init::<TIMER1_ADDR>(),
        Timer::init::<TIMER2_ADDR>(),
        Timer::init::<TIMER3_ADDR>(),
    );
    timers.0.set_cmp(INTERVAL);
    timers.1.set_cmp(2 * INTERVAL);
    timers.2.set_cmp(3 * INTERVAL);
    timers.3.set_cmp(4 * INTERVAL);

    sprintln!("dispatching 4 timers...");

    // Enable interrupts globally and dispatch all timers
    timers.0.enable();
    timers.1.enable();
    timers.2.enable();
    timers.3.enable();
    mtimer.enable();
    unsafe { riscv::interrupt::enable() };

    // Wait for timeout from timer
    while !unsafe { TIMEOUT } {
        wfi();
    }

    riscv::interrupt::disable();

    // Tear down after timeout
    tear_irq(Interrupt::Timer0Cmp);
    tear_irq(Interrupt::Timer1Cmp);
    tear_irq(Interrupt::Timer2Cmp);
    tear_irq(Interrupt::Timer3Cmp);
    tear_irq(Interrupt::MachineTimer);

    let all_flags = (0b1 << Interrupt::Timer0Cmp as u64)
        | (0b1 << Interrupt::Timer1Cmp as u64)
        | (0b1 << Interrupt::Timer2Cmp as u64)
        | (0b1 << Interrupt::Timer3Cmp as u64);
    // Safety: all interrupt handlers have already been run and there will not be a
    // race on IRQ_RECVD.
    assert_eq!(all_flags, unsafe { IRQ_RECVD });

    signal_pass(Some(&mut serial));
    loop {
        // Wait for interrupt
        wfi();
    }
}

#[interrupt]
fn Timer0Cmp() {
    unsafe { Timer::instance::<TIMER0_ADDR>() }.disable();
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
}

#[interrupt]
fn Timer1Cmp() {
    unsafe { Timer::instance::<TIMER1_ADDR>() }.disable();
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
}

#[interrupt]
fn Timer2Cmp() {
    unsafe { Timer::instance::<TIMER2_ADDR>() }.disable();
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
}

#[interrupt]
fn Timer3Cmp() {
    unsafe { Timer::instance::<TIMER3_ADDR>() }.disable();
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);
    // Safety: can't race, interrupts are disabled during the interrupt handler
    unsafe { IRQ_RECVD |= 0b1 << irq_code };
}

#[interrupt]
fn MachineTimer() {
    unsafe { TIMEOUT = true };
    MTimer::instance().reset();
}
