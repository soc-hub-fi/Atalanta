#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use core::arch::asm;
use more_asserts as ma;

use bsp::{
    clic::{Clic, Polarity, Trig},
    embedded_io::Write,
    interrupt,
    mmap::apb_timer::{TIMER0_ADDR, TIMER1_ADDR, TIMER2_ADDR, TIMER3_ADDR},
    mtimer::{self, MTimer},
    nested_interrupt,
    riscv::{
        self,
        asm::{nop, wfi},
    },
    rt::entry,
    sprint, sprintln,
    tb::signal_pass,
    timer_group::Timer,
    uart::*,
    Interrupt, CPU_FREQ,
};
use ufmt::derive::uDebug;

#[cfg_attr(feature = "ufmt", derive(uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
struct Task {
    level: u8,
    period_ns: u32,
    duration_ns: u32,
}

const RUN_COUNT: usize = 1;
const TEST_DURATION: mtimer::Duration = mtimer::Duration::micros(1_000);

impl Task {
    pub const fn new(level: u8, period_ns: u32, duration_ns: u32) -> Self {
        Self {
            period_ns,
            duration_ns,
            level,
        }
    }
}

const TEST_BASE_PERIOD_NS: u32 = 100_000;
const TASK0: Task = Task::new(
    1,
    TEST_BASE_PERIOD_NS / 4,
    /* 25 ‰) */ TEST_BASE_PERIOD_NS / 40,
);
const TASK1: Task = Task::new(
    2,
    TEST_BASE_PERIOD_NS / 8,
    /* 12,5 ‰) */ TEST_BASE_PERIOD_NS / 80,
);
const TASK2: Task = Task::new(
    3,
    TEST_BASE_PERIOD_NS / 16,
    /* 5 ‰) */ TEST_BASE_PERIOD_NS / 200,
);
const TASK3: Task = Task::new(
    4,
    TEST_BASE_PERIOD_NS / 32,
    /* 2,5 ‰) */ TEST_BASE_PERIOD_NS / 400,
);
const PERIPH_CLK_DIV: u64 = 1;
const CYCLES_PER_SEC: u64 = CPU_FREQ as u64 / PERIPH_CLK_DIV;
const CYCLES_PER_MS: u64 = CYCLES_PER_SEC / 1_000;
const CYCLES_PER_US: u32 = CYCLES_PER_MS as u32 / 1_000;
// !!!: this would saturate to zero, so we must not use it. Use `X *
// CYCLES_PER_US / 1_000 instead` and verify the output value is not saturated.
/* const CYCLES_PER_NS: u64 = CYCLES_PER_US / 1_000; */

static mut TASK0_COUNT: usize = 0;
static mut TASK1_COUNT: usize = 0;
static mut TASK2_COUNT: usize = 0;
static mut TASK3_COUNT: usize = 0;
static mut TIMEOUT: bool = false;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, 115_200);
    sprintln!("[periodic_tasks (PCS={:?})]", cfg!(feature = "pcs"));
    sprintln!("Running test {} times", RUN_COUNT);

    sprintln!(
        "Tasks: \r\n  {:?}\r\n  {:?}\r\n  {:?}\r\n  {:?}",
        TASK0,
        TASK1,
        TASK2,
        TASK3
    );
    sprintln!(
        "Test duration: {} us ({} ns)",
        TEST_DURATION.to_micros(),
        TEST_DURATION.to_nanos()
    );

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Timer0Cmp, TASK0.level);
    setup_irq(Interrupt::Timer1Cmp, TASK1.level);
    setup_irq(Interrupt::Timer2Cmp, TASK2.level);
    setup_irq(Interrupt::Timer3Cmp, TASK3.level);
    setup_irq(Interrupt::MachineTimer, u8::MAX);
    #[cfg(feature = "pcs")]
    {
        Clic::ie(Interrupt::Timer0Cmp).set_pcs(true);
        Clic::ie(Interrupt::Timer1Cmp).set_pcs(true);
        Clic::ie(Interrupt::Timer2Cmp).set_pcs(true);
        Clic::ie(Interrupt::Timer3Cmp).set_pcs(true);
    }

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
            Timer::init::<TIMER0_ADDR>(),
            Timer::init::<TIMER1_ADDR>(),
            Timer::init::<TIMER2_ADDR>(),
            Timer::init::<TIMER3_ADDR>(),
        );

        timers.0.set_cmp(TASK0.period_ns * CYCLES_PER_US / 1_000);
        timers.1.set_cmp(TASK1.period_ns * CYCLES_PER_US / 1_000);
        timers.2.set_cmp(TASK2.period_ns * CYCLES_PER_US / 1_000);
        timers.3.set_cmp(TASK3.period_ns * CYCLES_PER_US / 1_000);

        // --- Test critical ---
        unsafe {
            asm!("fence");
            // clear mcycle, minstret at start of critical section
            asm!("csrw 0xB00, {0}", in(reg) 0x0);
            asm!("csrw 0xB02, {0}", in(reg) 0x0);
            /* !!! mcycle and minstret are missing write-methdods in BSP !!! */
        };

        // Test will end when MachineTimer fires
        mtimer.start(TEST_DURATION);
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

        unsafe {
            let mcycle = riscv::register::mcycle::read64();
            let minstret = riscv::register::minstret::read64();

            sprintln!("cycles: {}", mcycle);
            sprintln!("instrs: {}", minstret);
            sprintln!(
                "Task counts:\r\n{} | {} | {} | {}",
                TASK0_COUNT,
                TASK1_COUNT,
                TASK2_COUNT,
                TASK3_COUNT
            );
            let total_ns_in_task0 = TASK0.duration_ns * TASK0_COUNT as u32;
            let total_ns_in_task1 = TASK1.duration_ns * TASK1_COUNT as u32;
            let total_ns_in_task2 = TASK2.duration_ns * TASK2_COUNT as u32;
            let total_ns_in_task3 = TASK3.duration_ns * TASK3_COUNT as u32;
            sprintln!(
                "Theoretical total duration spent in task workload (ns):\r\n{} | {} | {} | {} = {}",
                total_ns_in_task0,
                total_ns_in_task1,
                total_ns_in_task2,
                total_ns_in_task3,
                total_ns_in_task0 + total_ns_in_task1 + total_ns_in_task2 + total_ns_in_task3,
            );

            // Assert that each task runs the expected number of times
            for (count, task) in &[
                (TASK0_COUNT, TASK0),
                (TASK1_COUNT, TASK1),
                (TASK2_COUNT, TASK2),
                (TASK3_COUNT, TASK3),
            ] {
                // Assert task count is at least the expected count. There may be one less as the
                // final in-flight task might get interrupted by the test end.
                ma::assert_ge!(
                    *count,
                    (TEST_DURATION.to_nanos() as usize / task.period_ns as usize) - 1
                );
                ma::assert_le!(
                    *count,
                    (TEST_DURATION.to_nanos() as usize / task.period_ns as usize)
                );
            }

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
    #[cfg(feature = "pcs")]
    {
        Clic::ie(Interrupt::Timer0Cmp).set_pcs(false);
        Clic::ie(Interrupt::Timer1Cmp).set_pcs(false);
        Clic::ie(Interrupt::Timer2Cmp).set_pcs(false);
        Clic::ie(Interrupt::Timer3Cmp).set_pcs(false);
    }

    signal_pass(Some(&mut serial));
    loop {
        // Wait for interrupt
        wfi();
    }
}

#[cfg_attr(feature = "pcs", nested_interrupt(pcs))]
#[cfg_attr(not(feature = "pcs"), nested_interrupt)]
unsafe fn Timer0Cmp() {
    TASK0_COUNT += 1;
    let workload = TASK0.duration_ns * CYCLES_PER_US / 1_000;
    for _ in 0..workload {
        nop();
    }
}

#[cfg_attr(feature = "pcs", nested_interrupt(pcs))]
#[cfg_attr(not(feature = "pcs"), nested_interrupt)]
unsafe fn Timer1Cmp() {
    TASK1_COUNT += 1;
    let workload = TASK1.duration_ns * CYCLES_PER_US / 1_000;
    for _ in 0..workload {
        nop();
    }
}

#[cfg_attr(feature = "pcs", nested_interrupt(pcs))]
#[cfg_attr(not(feature = "pcs"), nested_interrupt)]
unsafe fn Timer2Cmp() {
    TASK2_COUNT += 1;
    let workload = TASK2.duration_ns * CYCLES_PER_US / 1_000;
    for _ in 0..workload {
        nop();
    }
}

#[cfg_attr(feature = "pcs", nested_interrupt(pcs))]
#[cfg_attr(not(feature = "pcs"), nested_interrupt)]
unsafe fn Timer3Cmp() {
    TASK3_COUNT += 1;
    let workload = TASK3.duration_ns * CYCLES_PER_US / 1_000;
    for _ in 0..workload {
        nop();
    }
}

/// Timeout interrupt (per test-run)
#[interrupt]
unsafe fn MachineTimer() {
    unsafe { TIMEOUT = true };
    let mut timer = MTimer::instance();
    timer.disable();

    // Draw mtimer to max value to make sure all currently pending or in flight
    // TimerXCmp interrupts fall through.
    timer.set_counter(u64::MAX);

    // Disable all timers & interrupts, so no more instances will fire
    Timer::instance::<TIMER0_ADDR>().disable();
    Timer::instance::<TIMER1_ADDR>().disable();
    Timer::instance::<TIMER2_ADDR>().disable();
    Timer::instance::<TIMER3_ADDR>().disable();
    Clic::ip(Interrupt::MachineTimer).unpend();
    Clic::ip(Interrupt::Timer0Cmp).unpend();
    Clic::ip(Interrupt::Timer1Cmp).unpend();
    Clic::ip(Interrupt::Timer2Cmp).unpend();
    Clic::ip(Interrupt::Timer3Cmp).unpend();
}

pub fn setup_irq(irq: Interrupt, level: u8) {
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
pub fn tear_irq(irq: Interrupt) {
    Clic::ie(irq).disable();
    Clic::ctl(irq).set_level(0x0);
    Clic::attr(irq).set_shv(false);
    Clic::attr(irq).set_trig(Trig::Level);
    Clic::attr(irq).set_polarity(Polarity::Pos);
}
