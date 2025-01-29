//!
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use bsp::{
    asm_delay,
    clic::{Clic, InterruptNumber, Polarity, Trig},
    nested_interrupt,
    riscv::{self, asm::wfi},
    rt::entry,
    sprint, sprintln,
    tb::signal_pass,
    timer_group::{Timer0, Timer1, Timer2, Timer3},
    uart::*,
    Interrupt, CPU_FREQ, NOPS_PER_SEC,
};
use hello_rt::{print_example_name, tear_irq, UART_BAUD};
use ufmt::derive::uDebug;

#[cfg_attr(feature = "ufmt", derive(uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
struct Task {
    period_ms: u32,
    duration_ms: u32,
    prio: u8,
}

impl Task {
    pub const fn new(prio: u8, period_ms: u32, duration_ms: u32) -> Self {
        Self {
            period_ms,
            duration_ms,
            prio,
        }
    }
}

const TEST_DURATION_SEC: u32 = 1;
const TASK0: Task = Task::new(4, 400, 2);
const TASK1: Task = Task::new(3, 600, 2);
const TASK2: Task = Task::new(2, 200, 2);
const TASK3: Task = Task::new(1, 800, 2);

static mut TASK0_COUNT: usize = 0;
static mut TASK1_COUNT: usize = 0;
static mut TASK2_COUNT: usize = 0;
static mut TASK3_COUNT: usize = 0;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Timer0Cmp, TASK0.prio);
    setup_irq(Interrupt::Timer1Cmp, TASK1.prio);
    setup_irq(Interrupt::Timer2Cmp, TASK2.prio);
    setup_irq(Interrupt::Timer3Cmp, TASK3.prio);

    let mut timers = (
        Timer0::init(),
        Timer1::init(),
        Timer2::init(),
        Timer3::init(),
    );

    timers.0.set_cmp(TASK0.period_ms * NOPS_PER_SEC / 1000);
    timers.1.set_cmp(TASK1.period_ms * NOPS_PER_SEC / 1000);
    timers.2.set_cmp(TASK2.period_ms * NOPS_PER_SEC / 1000);
    timers.3.set_cmp(TASK3.period_ms * NOPS_PER_SEC / 1000);

    sprintln!(
        "Tasks: \r\n  {:?}\r\n  {:?}\r\n  {:?}\r\n  {:?}",
        TASK0,
        TASK1,
        TASK2,
        TASK3
    );
    sprintln!(
        "dispatching 4 timers, test duration: {} s",
        TEST_DURATION_SEC
    );

    // Enable interrupts globally and dispatch all timers
    unsafe { riscv::interrupt::enable() };
    timers.0.enable();
    timers.1.enable();
    timers.2.enable();
    timers.3.enable();

    // HACK: timeout using asm delay, while mtimer is unstable
    asm_delay(TEST_DURATION_SEC * NOPS_PER_SEC);

    riscv::interrupt::disable();
    // Tear down after timeout
    tear_irq(Interrupt::Timer0Cmp);
    tear_irq(Interrupt::Timer1Cmp);
    tear_irq(Interrupt::Timer2Cmp);
    tear_irq(Interrupt::Timer3Cmp);

    // Safety: interrupt handlers have been torn down, no race
    unsafe {
        sprintln!(
            "Task counts:\r\n{} | {} | {} | {}",
            TASK0_COUNT,
            TASK1_COUNT,
            TASK2_COUNT,
            TASK3_COUNT
        );
        sprintln!(
            "Theoretical total duration spent in task workload (ms):\r\n{} | {} | {} | {} = {}",
            TASK0.duration_ms * TASK0_COUNT as u32,
            TASK1.duration_ms * TASK1_COUNT as u32,
            TASK2.duration_ms * TASK2_COUNT as u32,
            TASK3.duration_ms * TASK3_COUNT as u32,
            TASK0.duration_ms * TASK0_COUNT as u32
                + TASK1.duration_ms * TASK1_COUNT as u32
                + TASK2.duration_ms * TASK2_COUNT as u32
                + TASK3.duration_ms * TASK3_COUNT as u32,
        );
    }

    signal_pass(Some(&mut serial));
    loop {
        // Wait for interrupt
        wfi();
    }
}

#[nested_interrupt]
fn Timer0Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK0.duration_ms * NOPS_PER_SEC / 1000);
        TASK0_COUNT += 1;
    };
}

#[nested_interrupt]
fn Timer1Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK1.duration_ms * NOPS_PER_SEC / 1000);
        TASK1_COUNT += 1;
    };
}

#[nested_interrupt]
fn Timer2Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK2.duration_ms * NOPS_PER_SEC / 1000);
        TASK2_COUNT += 1;
    };
}

#[nested_interrupt]
fn Timer3Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK3.duration_ms * NOPS_PER_SEC / 1000);
        TASK3_COUNT += 1;
    };
}

pub fn setup_irq(irq: Interrupt, level: u8) {
    sprintln!("set up IRQ: {}", irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}
