//! UART pin map, incl. PYNQ-Z1:
//!
//! | Host  | Device    | PYNQ-Z1 |
//! | :-:   | :-:       | :-:     |
//! | TX    | RX        | IO12    |
//! | RX    | TX        | IO13    |
#![no_main]
#![no_std]
#![allow(non_snake_case)]
#![allow(static_mut_refs)]

#[cfg(not(any(feature = "use-hwq", feature = "use-imap", feature = "use-bheap")))]
compile_error!("must select `use-hwq`, `use-imap`, or `use-bheap`");

use bsp::{
    clic::Clic,
    interrupt,
    mmap::{CFG_BASE, PERIPH_CLK_DIV_OFS},
    mtimer::{self, MTimer},
    register::mcycle,
    riscv::{self, asm::wfi},
    rt::entry,
    sprint, sprintln,
    timer_queue::TimerQueue,
    uart::*,
    write_u32, Interrupt, CPU_FREQ,
};
use pqbench::{
    abstract_drop, abstract_insert, print_example_name, setup_irq, tear_irq, PQueue, UART_BAUD,
};

const PERIPH_CLK_DIV: u64 = 1;
const TEST_DURATION: mtimer::Duration = mtimer::Duration::micros(1);

/// Main queue length
const Q_LEN: usize = if cfg!(not(feature = "virtq")) { 256 } else { 8 };
/// Software priority queue implemented as binary heap
static mut SW_PQ: Option<PQueue<Q_LEN>> = Some(PQueue::new());

/// Backup queue len
const B_LEN: usize = 256 - 8;
static mut BACKUP: Option<heapless::Deque<pqbench::Entry, B_LEN>> = Some(heapless::Deque::new());

static mut TIMEOUT: bool = false;

static mut FREE_HANDLES: heapless::Deque<u8, 256> = heapless::Deque::<u8, 256>::new();

fn prof<F>(s: &str, f: F)
where
    F: FnOnce() -> (),
{
    let mc0 = mcycle::read();
    f();
    let mc1 = mcycle::read();
    sprintln!("{} took {} cycles", s, mc1 - mc0);
}

#[entry]
fn main() -> ! {
    // Assert that periph clk div is as configured
    // !!!: this must be done prior to configuring any timing sensitive
    // peripherals
    write_u32(CFG_BASE + PERIPH_CLK_DIV_OFS, PERIPH_CLK_DIV as u32);

    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    sprintln!(
        "{} priority queue length is {}",
        if cfg!(feature = "use-hwq") {
            "Hardware"
        } else {
            "Software"
        },
        Q_LEN,
    );
    #[cfg(feature = "virtq")]
    sprintln!(
        "Queue is virtualized with a backup queue of length {}",
        B_LEN
    );

    sprint!("Setup interrupts...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::TqFull, 6);
    // Refill hardware queue at low priority
    setup_irq(Interrupt::TqNotFull, 1);
    setup_irq(Interrupt::MachineTimer, u8::MAX);
    setup_irq(Interrupt::TqId0, 2);
    sprintln!(" done");

    let tq = TimerQueue::init();
    let handle_bounds = if cfg!(feature = "virtq") {
        tq.capacity()..(tq.capacity() + B_LEN as u32)
    } else {
        0u32..Q_LEN as u32
    };
    for h in handle_bounds {
        unsafe { FREE_HANDLES.push_back(h as u8).unwrap() }
    }

    // === TEST STARTS ===

    let _timer_q = TimerQueue::init();

    unsafe {
        let mut handles = heapless::Vec::<u8, 256>::new();
        for n in 0..16 {
            let mut s = heapless::String::<16>::new();
            #[cfg(feature = "ufmt")]
            ufmt::uwrite!(s, "insert {}", n).ok();
            #[cfg(not(feature = "ufmt"))]
            {
                use core::fmt::Write;
                write!(s, "insert {}", n).ok();
            }
            prof(&s, || {
                let swq = SW_PQ.as_mut().unwrap_unchecked();
                let bq = BACKUP.as_mut().unwrap_unchecked();
                let h = abstract_insert(0, (0b1 << 24) - 1, swq, &mut FREE_HANDLES, bq);
                handles.push(h).unwrap_unchecked();
            });
        }

        for h in handles {
            let mut s = heapless::String::<16>::new();
            ufmt::uwrite!(s, "drop {}", h).ok();
            prof(&s, || {
                let swq = SW_PQ.as_mut().unwrap_unchecked();
                let bq = BACKUP.as_mut().unwrap_unchecked();
                abstract_drop(h, swq, &mut FREE_HANDLES, bq);
            });
        }
    }

    // Init mtimer
    sprintln!("Start mtimer");
    let mut mtimer = MTimer::instance().into_oneshot();

    // Test will end when MachineTimer fires
    mtimer.start(TEST_DURATION);

    // TODO: insert 2
    // TODO: drop 2

    // TODO: insert 4
    // TODO: drop 4

    // TODO: insert ...
    // TODO: drop ...

    // This benchmark requires the main queue to be 256 deep
    //assert!(timer_q.capacity() >= Q_LEN);

    // Enable interrupts globally
    sprintln!("interrupt::enable");
    unsafe { riscv::interrupt::enable() };

    while !unsafe { TIMEOUT } {
        sprintln!("wfi");
        wfi();
    }

    // === TEST ENDS ===

    sprintln!("Interrupt count {}", unsafe { CNT });

    bsp::tb::signal_pass(Some(&mut serial));
    loop {}
}

#[interrupt]
fn TqFull() {
    sprintln!("IRQ:TqFull");
}

// Hardware reports that there is space in the hardware queue
// => restore elements from backup to hardware queue
#[interrupt]
fn TqNotFull() {
    sprintln!("IRQ:TqNotFull");

    let mut tq = unsafe { TimerQueue::instance() };
    let bq = unsafe { BACKUP.as_mut().unwrap() };
    let mut refill_count = 0;
    while !tq.is_full() && !bq.is_empty() {
        let f = unsafe { bq.pop_front().unwrap_unchecked() };
        unsafe { FREE_HANDLES.push_back(f.1).unwrap() };
        tq.push_abs(f.0);
        refill_count += 1;
    }

    sprintln!("Refilled {} elements", refill_count);
}

static mut CNT: u32 = 0;

#[interrupt]
fn TqId0() {
    sprintln!("IRQ:TqId0");
    // Safety: CNT is not shared during test run
    unsafe { CNT += 1 };
}

/// Test timeout interrupt (per test-run)
#[interrupt]
unsafe fn MachineTimer() {
    sprintln!("IRQ:MachineTimer");
    unsafe { TIMEOUT = true };

    tear_irq(Interrupt::TqFull);
    tear_irq(Interrupt::TqNotFull);
    tear_irq(Interrupt::MachineTimer);
    tear_irq(Interrupt::TqId0);
}

#[export_name = "DefaultHandler"]
fn default_handler() {
    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!("IRQ:DefaultHandler {}", irq_code);
}
