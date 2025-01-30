//!
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use core::arch::asm;

use bsp::{
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
    unmask_u32, Interrupt, CPU_FREQ,
};
use fugit::ExtU64;
use hello_rt::{print_example_name, tear_irq, UART_BAUD};
use ufmt::derive::uDebug;

#[cfg_attr(feature = "ufmt", derive(uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
struct Task {
    level: u8,
    period_us: u32,
    duration_us: u32,
    start_offset_us: u32,
}

const RUN_COUNT: usize = 1;

impl Task {
    pub const fn new(level: u8, period_us: u32, duration_us: u32, start_offset_us: u32) -> Self {
        Self {
            period_us,
            duration_us,
            level,
            start_offset_us,
        }
    }
}

const TEST_DURATION_US: u32 = 500;
const TASK0: Task = Task::new(
    1,
    TEST_DURATION_US / 1,
    /* 20 % */ TEST_DURATION_US / 5,
    /* 10 % */ TEST_DURATION_US / 10,
);
const TASK1: Task = Task::new(
    2,
    TEST_DURATION_US / 1,
    /* 10 % */ TEST_DURATION_US / 10,
    /* 60 % */ 3 * TEST_DURATION_US / 5,
);
const TASK2: Task = Task::new(
    3,
    TEST_DURATION_US / 2,
    /* 5 % */ TEST_DURATION_US / 20,
    /* 37.5 % */ 3 * TEST_DURATION_US / 8,
);
const TASK3: Task = Task::new(
    4,
    TEST_DURATION_US / 4,
    /* 2.5 % */ TEST_DURATION_US / 40,
    /* 12.5 % */ TEST_DURATION_US / 8,
);
const PERIPH_CLK_DIV: u64 = 2;
const CYCLES_PER_SEC: u64 = CPU_FREQ as u64 / PERIPH_CLK_DIV;
const CYCLES_PER_MS: u64 = CYCLES_PER_SEC / 1_000;
const CYCLES_PER_US: u64 = CYCLES_PER_MS / 1_000;

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

    setup_irq(Interrupt::Timer0Cmp, TASK0.level);
    setup_irq(Interrupt::Timer1Cmp, TASK1.level);
    setup_irq(Interrupt::Timer2Cmp, TASK2.level);
    setup_irq(Interrupt::Timer3Cmp, TASK3.level);
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

            // Make sure serial is done printing before proceeding to the test case
            serial.flush().unwrap_unchecked();
        }
        // Use mtimer for timeout
        let mut mtimer = MTimer::instance().into_oneshot();

        let mut timers = (
            Timer0::init(),
            Timer1::init(),
            Timer2::init(),
            Timer3::init(),
        );

        timers.0.set_cmp(TASK0.period_us * CYCLES_PER_US as u32);
        timers.1.set_cmp(TASK1.period_us * CYCLES_PER_US as u32);
        timers.2.set_cmp(TASK2.period_us * CYCLES_PER_US as u32);
        timers.3.set_cmp(TASK3.period_us * CYCLES_PER_US as u32);
        timers
            .0
            .set_counter((TASK0.period_us - TASK0.start_offset_us) * CYCLES_PER_US as u32);
        timers
            .1
            .set_counter((TASK1.period_us - TASK1.start_offset_us) * CYCLES_PER_US as u32);
        timers
            .2
            .set_counter((TASK2.period_us - TASK2.start_offset_us) * CYCLES_PER_US as u32);
        timers
            .3
            .set_counter((TASK3.period_us - TASK3.start_offset_us) * CYCLES_PER_US as u32);

        // --- Test critical ---
        unsafe { asm!("fence") };

        // Test will end when MachineTimer fires
        mtimer.start((TEST_DURATION_US as u64).micros());
        timers.0.enable();
        timers.1.enable();
        timers.2.enable();
        timers.3.enable();

        unsafe { riscv::interrupt::enable() };

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
            Clic::ip(Interrupt::MachineTimer).unpend();
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
unsafe fn Timer0Cmp() {
    let plevel: u8;
    asm!("csrrw {0}, 0x347, {1}", out(reg) plevel, in(reg) TASK0.level);
    let mtimer = MTimer::instance();
    let sample = mtimer.counter();
    TASK0_COUNT += 1;
    let task_end = sample + TASK0.duration_us as u64 * CYCLES_PER_US;
    while mtimer.counter() <= task_end {}
    asm!("csrw 0x347, {0}", in(reg) plevel);
}

#[nested_interrupt(pcs)]
unsafe fn Timer1Cmp() {
    let plevel: u8;
    asm!("csrrw {0}, 0x347, {1}", out(reg) plevel, in(reg) TASK1.level);
    let mtimer: MTimer = MTimer::instance();
    let sample = mtimer.counter();
    TASK1_COUNT += 1;
    let task_end = sample + TASK1.duration_us as u64 * CYCLES_PER_US;
    while mtimer.counter() <= task_end {}
    asm!("csrw 0x347, {0}", in(reg) plevel);
}

#[nested_interrupt(pcs)]
unsafe fn Timer2Cmp() {
    let plevel: u8;
    asm!("csrrw {0}, 0x347, {1}", out(reg) plevel, in(reg) TASK2.level);
    let mtimer = MTimer::instance();
    let sample = mtimer.counter();
    TASK2_COUNT += 1;
    let task_end = sample + TASK2.duration_us as u64 * CYCLES_PER_US;
    while mtimer.counter() <= task_end {}
    asm!("csrw 0x347, {0}", in(reg) plevel);
}

#[nested_interrupt(pcs)]
unsafe fn Timer3Cmp() {
    let plevel: u8;
    asm!("csrrw {0}, 0x347, {1}", out(reg) plevel, in(reg) TASK3.level);
    let mtimer = MTimer::instance();
    let sample = mtimer.counter();
    TASK3_COUNT += 1;
    let task_end = sample + TASK3.duration_us as u64 * CYCLES_PER_US;
    while mtimer.counter() <= task_end {}
    asm!("csrw 0x347, {0}", in(reg) plevel);
}

#[interrupt]
unsafe fn MachineTimer() {
    unsafe { TIMEOUT = true };
    let mut timer = MTimer::instance();
    timer.disable();

    // Draw mtimer to max value to make sure all currently pending or in flight
    // TimerXCmp interrupts fall through.
    timer.set_counter(u64::MAX);

    Clic::ip(Interrupt::MachineTimer).unpend();
    Clic::ip(Interrupt::Timer0Cmp).unpend();
    Clic::ip(Interrupt::Timer1Cmp).unpend();
    Clic::ip(Interrupt::Timer2Cmp).unpend();
    Clic::ip(Interrupt::Timer3Cmp).unpend();
}

pub fn setup_irq(irq: Interrupt, level: u8) {
    sprintln!("Set up {:?} (id = {})", irq, irq.number());
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}
