//! Take measurements of mtimer and convert them to real-time
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use bsp::{
    clic::Clic,
    mmap::apb_timer::TIMER0_ADDR,
    mtimer::MTimer,
    riscv::{self, asm::wfi},
    rt::{entry, interrupt},
    sprintln,
    timer_group::Timer,
    uart::ApbUart,
    Interrupt, CPU_FREQ,
};
use fugit::ExtU64;
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

static mut IRQ_COUNTER: usize = 0;
static mut T0_COUNTER: usize = 0;
const PERIPH_CLK_DIV: u32 = 2;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    let mut mtimer = MTimer::instance().into_oneshot();
    setup_irq(Interrupt::MachineTimer);

    let mut t0 = Timer::init::<TIMER0_ADDR>();
    setup_irq(Interrupt::Timer0Cmp);

    unsafe {
        mtimer.start(1u64.secs());

        t0.set_cmp(CPU_FREQ / PERIPH_CLK_DIV);
        t0.enable();

        riscv::interrupt::enable();
    }

    while unsafe { IRQ_COUNTER != 10 } {
        wfi();
    }
    riscv::interrupt::disable();

    // Clean up
    tear_irq(Interrupt::MachineTimer);
    tear_irq(Interrupt::Timer0Cmp);

    bsp::tb::signal_pass(Some(&mut serial));
    loop {}
}

#[interrupt]
unsafe fn MachineTimer() {
    unsafe { IRQ_COUNTER += 1 };
    let mtimer = MTimer::instance();
    let sample = mtimer.counter();
    let mut mtimer = mtimer.into_oneshot();
    mtimer.start(1u64.secs());
    sprintln!("Seconds passed: {} (mtimer = {})", IRQ_COUNTER, sample);
}

#[interrupt]
unsafe fn Timer0Cmp() {
    unsafe { T0_COUNTER += 1 };
    let t0 = unsafe { Timer::instance::<TIMER0_ADDR>() };
    sprintln!("Seconds passed: {} (t0 = {})", T0_COUNTER, t0.counter());
}
