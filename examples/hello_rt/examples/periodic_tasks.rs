//!
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use core::arch::asm;

use bsp::{
    asm_delay,
    clic::{Clic, InterruptNumber, Polarity, Trig},
    embedded_io::Write,
    mask_u32,
    mmap::CLIC_BASE_ADDR,
    mtimer::MTimer,
    nested_interrupt,
    riscv::{self, asm::wfi},
    rt::{entry, interrupt},
    sprint, sprintln,
    tb::signal_pass,
    timer_group::{Timer0, Timer1, Timer2, Timer3},
    uart::*,
    unmask_u32, Interrupt, CPU_FREQ, NOPS_PER_SEC,
};
use hello_rt::{print_example_name, tear_irq, UART_BAUD};
use ufmt::derive::uDebug;

const NOPS_PER_MS: u32 = NOPS_PER_SEC / 1000;
const NOPS_PER_US: u32 = NOPS_PER_MS / 1000;

#[cfg_attr(feature = "ufmt", derive(uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
struct Task {
    period_us: u32,
    duration_us: u32,
    prio: u8,
}

impl Task {
    pub const fn new(prio: u8, period_us: u32, duration_us: u32) -> Self {
        Self {
            period_us,
            duration_us,
            prio,
        }
    }
}

const TEST_DURATION_US: u64 = 250;
const TASK0: Task = Task::new(4, TEST_DURATION_US as u32 / 5, 2);
const TASK1: Task = Task::new(3, TEST_DURATION_US as u32 / 4, 2);
const TASK2: Task = Task::new(2, TEST_DURATION_US as u32 / 10, 2);
const TASK3: Task = Task::new(1, TEST_DURATION_US as u32 / 3, 2);

static mut TASK0_COUNT: usize = 0;
static mut TASK1_COUNT: usize = 0;
static mut TASK2_COUNT: usize = 0;
static mut TASK3_COUNT: usize = 0;
static mut TIMEOUT: bool = false;

fn enable_pcs(irq: Interrupt) {
    const PCS_BIT_IDX: u32 = 12;
    mask_u32(
        CLIC_BASE_ADDR + 0x1000 + 0x04 * irq as usize,
        0b1 << PCS_BIT_IDX,
    );
}

fn disable_pcs(irq: Interrupt) {
    const PCS_BIT_IDX: u32 = 12;
    unmask_u32(
        CLIC_BASE_ADDR + 0x1000 + 0x04 * irq as usize,
        0b1 << PCS_BIT_IDX,
    );
}

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    const RUN_COUNT: usize = 5;
    sprintln!("Running test {} times", RUN_COUNT);

    sprintln!(
        "Tasks: \r\n  {:?}\r\n  {:?}\r\n  {:?}\r\n  {:?}",
        TASK0,
        TASK1,
        TASK2,
        TASK3
    );
    sprintln!("Test duration: {} us", TEST_DURATION_US);

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Timer0Cmp, TASK0.prio);
    setup_irq(Interrupt::Timer1Cmp, TASK1.prio);
    setup_irq(Interrupt::Timer2Cmp, TASK2.prio);
    setup_irq(Interrupt::Timer3Cmp, TASK3.prio);
    setup_irq(Interrupt::MachineTimer, u8::MAX);
    enable_pcs(Interrupt::Timer0Cmp);
    enable_pcs(Interrupt::Timer1Cmp);
    enable_pcs(Interrupt::Timer2Cmp);
    enable_pcs(Interrupt::Timer3Cmp);

    for run_idx in 0..RUN_COUNT {
        sprintln!("Run {}", run_idx);
        // SAFETY: interrupts off
        unsafe {
            TASK0_COUNT = 0;
            TASK1_COUNT = 0;
            TASK2_COUNT = 0;
            TASK3_COUNT = 0;
            TIMEOUT = false;
            // Make sure serial is done printing before proceeding to the next iteration
            serial.flush().unwrap_unchecked();
        }

        // --- Test critical ---
        unsafe { asm!("fence") };
        let mut timers = (
            Timer0::init(),
            Timer1::init(),
            Timer2::init(),
            Timer3::init(),
        );

        timers.0.set_cmp(TASK0.period_us * NOPS_PER_US);
        timers.1.set_cmp(TASK1.period_us * NOPS_PER_US);
        timers.2.set_cmp(TASK2.period_us * NOPS_PER_US);
        timers.3.set_cmp(TASK3.period_us * NOPS_PER_US);

        // Use mtimer for timeout
        let mut mtimer = MTimer::init();
        let counter = unsafe { mtimer.counter() };
        mtimer.enable();
        let timeout = counter + TEST_DURATION_US * NOPS_PER_US as u64;
        unsafe { mtimer.set_cmp(timeout) };

        // Enable interrupts globally and dispatch all timers
        unsafe { riscv::interrupt::enable() };
        timers.0.enable();
        timers.1.enable();
        timers.2.enable();
        timers.3.enable();

        while !unsafe { TIMEOUT } {
            wfi();
        }

        riscv::interrupt::disable();
        unsafe { asm!("fence") };
        // --- Test critical end ---

        // Safety: interrupt handlers have been torn down, no race
        unsafe {
            timers.0.reset();
            timers.1.reset();
            timers.2.reset();
            timers.3.reset();
            Clic::ip(Interrupt::Timer0Cmp).unpend();
            Clic::ip(Interrupt::Timer1Cmp).unpend();
            Clic::ip(Interrupt::Timer2Cmp).unpend();
            Clic::ip(Interrupt::Timer3Cmp).unpend();
            Clic::ip(Interrupt::MachineTimer);
            sprintln!(
                "Task counts:\r\n{} | {} | {} | {}",
                TASK0_COUNT,
                TASK1_COUNT,
                TASK2_COUNT,
                TASK3_COUNT
            );
            let total_in_task0 = TASK0.duration_us * TASK0_COUNT as u32;
            let total_in_task1 = TASK1.duration_us * TASK1_COUNT as u32;
            let total_in_task2 = TASK2.duration_us * TASK2_COUNT as u32;
            let total_in_task3 = TASK3.duration_us * TASK3_COUNT as u32;
            sprintln!(
                "Theoretical total duration spent in task workload (us):\r\n{} | {} | {} | {} = {}",
                total_in_task0,
                total_in_task1,
                total_in_task2,
                total_in_task3,
                total_in_task0 + total_in_task1 + total_in_task2 + total_in_task3,
            );
            // Make sure serial is done printing before proceeding to the next iteration
            serial.flush().unwrap_unchecked();
        }
    }

    // Clean up
    tear_irq(Interrupt::Timer0Cmp);
    tear_irq(Interrupt::Timer1Cmp);
    tear_irq(Interrupt::Timer2Cmp);
    tear_irq(Interrupt::Timer3Cmp);
    tear_irq(Interrupt::MachineTimer);
    disable_pcs(Interrupt::Timer0Cmp);
    disable_pcs(Interrupt::Timer1Cmp);
    disable_pcs(Interrupt::Timer2Cmp);
    disable_pcs(Interrupt::Timer3Cmp);

    signal_pass(Some(&mut serial));
    loop {
        // Wait for interrupt
        wfi();
    }
}

#[nested_interrupt(pcs)]
fn Timer0Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK0.duration_us * NOPS_PER_US);
        TASK0_COUNT += 1;
    };
}

#[nested_interrupt(pcs)]
fn Timer1Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK1.duration_us * NOPS_PER_US);
        TASK1_COUNT += 1;
    };
}

#[nested_interrupt(pcs)]
fn Timer2Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK2.duration_us * NOPS_PER_US);
        TASK2_COUNT += 1;
    };
}

#[nested_interrupt(pcs)]
fn Timer3Cmp() {
    // Safety: resources are unique to this task
    unsafe {
        asm_delay(TASK3.duration_us * NOPS_PER_US);
        TASK3_COUNT += 1;
    };
}

pub fn setup_irq(irq: Interrupt, level: u8) {
    sprintln!("Set up {:?} (id = {})", irq, irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}

#[interrupt]
fn MachineTimer() {
    unsafe { TIMEOUT = true };
    unsafe { MTimer::instance() }.reset();
}
