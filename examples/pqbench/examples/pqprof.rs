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
    uart::*,
    write_u32, Interrupt, CPU_FREQ,
};
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
use pqbench::VQueue;
use pqbench::{print_example_name, setup_irq, tear_irq, UART_BAUD};

const PERIPH_CLK_DIV: u64 = 1;
const TEST_DURATION: mtimer::Duration = mtimer::Duration::micros(1);

/// Main queue length
const Q_LEN: usize = if cfg!(not(feature = "virtq")) { 256 } else { 8 };

/// Backup queue len
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
const B_LEN: usize = 256 - 8;

#[cfg(all(feature = "use-hwq", not(feature = "virtq")))]
type TqT = bsp::timer_queue::TimerQueue;
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
type TqT = VQueue<Q_LEN, B_LEN>;
#[cfg(all(feature = "use-bheap"))]
type TqT = BHeap<Q_LEN>;
#[cfg(all(feature = "use-imap"))]
type TqT = IMap<Q_LEN>;

static mut SHARED_TQ: Option<TqT> = None;

static mut TIMEOUT: bool = false;

fn prof<F, O>(s: &str, f: F) -> O
where
    F: FnOnce() -> O,
{
    let mc0 = mcycle::read();
    let output = f();
    let mc1 = mcycle::read();
    sprintln!("{} took {} cycles", s, mc1 - mc0);

    output
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

    // === TEST STARTS ===

    let timer_q = match () {
        #[cfg(all(feature = "use-hwq", not(feature = "virtq")))]
        () => bsp::timer_queue::TimerQueue::init(),
        #[cfg(all(feature = "use-hwq", feature = "virtq"))]
        () => VQueue::new(),
        #[cfg(all(feature = "use-bheap"))]
        () => BHeap::new(),
        #[cfg(all(feature = "use-imap"))]
        () => IMap::new(),
    };

    unsafe {
        let _ = SHARED_TQ.insert(timer_q);
    }
    let timer_q = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };

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
        let h = prof(&s, || {
            timer_q.push_rel(bsp::timer_queue::Entry::new((0b1 << 24) - 1, 0))
        });
        unsafe { handles.push(h).unwrap_unchecked() };
    }

    for h in handles {
        let mut s = heapless::String::<16>::new();
        #[cfg(feature = "ufmt")]
        ufmt::uwrite!(s, "drop {}", h).ok();
        #[cfg(not(feature = "ufmt"))]
        {
            use core::fmt::Write;
            write!(s, "drop {}", h).ok();
        }
        prof(&s, || {
            timer_q.drop(h);
        });
    }

    // Init mtimer
    sprintln!("Start mtimer");
    let mut mtimer = MTimer::instance().into_oneshot();

    // Test will end when MachineTimer fires
    mtimer.start(TEST_DURATION);

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
#[cfg(feature = "virtq")]
#[interrupt]
fn TqNotFull() {
    sprintln!("IRQ:TqNotFull");

    let tq = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };

    let mut refill_count = 0;
    while !tq.tq.is_full() && !tq.bq.is_empty() {
        let f = unsafe { tq.bq.pop_front().unwrap_unchecked() };
        tq.free_handles.push_back(f.1).unwrap();
        // If encountered elem from dropq, do not restore but only drop instead
        if !tq.bq_dropq.contains(&f.1) {
            tq.tq.push_abs(f.0);
            refill_count += 1;
        } else {
            tq.bq_dropq.remove(&f.1);
        }
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
