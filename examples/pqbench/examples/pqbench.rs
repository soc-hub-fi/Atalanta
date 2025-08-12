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

use core::ops::AddAssign;

use bsp::{
    clic::Clic,
    interrupt,
    mmap::{apb_timer::TIMER0_ADDR, CFG_BASE, PERIPH_CLK_DIV_OFS},
    mtimer::{self, MTimer},
    nested_interrupt,
    riscv::{self, asm::wfi},
    rt::entry,
    sprint, sprintln,
    timer_group::{Duration, Timer},
    timer_queue::TimerQueue,
    uart::*,
    write_u32, Interrupt, CPU_FREQ,
};
use heapless::{binary_heap::Min, BinaryHeap, Deque};
use pqbench::{abstract_insert, print_example_name, setup_irq, tear_irq, UART_BAUD};
use rand::{RngCore, SeedableRng};

const PERIPH_CLK_DIV: u64 = 1;
const TEST_DURATION: mtimer::Duration = mtimer::Duration::micros(500);
const PUSH_PERIOD_US: u32 = 100;

/// Main queue length
const Q_LEN: usize = if cfg!(not(feature = "virtq")) { 256 } else { 8 };
/// Software priority queue implemented as binary heap
static mut SW_PQ: Option<BinaryHeap<pqbench::Entry, Min, Q_LEN>> = Some(BinaryHeap::new());

/// Backup queue len
const B_LEN: usize = 256 - 8;
static mut BACKUP: Option<Deque<pqbench::Entry, B_LEN>> = Some(Deque::new());

static mut TIMEOUT: bool = false;
static mut RNG: Option<rand::rngs::SmallRng> = None;

static mut FREE_HANDLES: heapless::Deque<u8, 256> = heapless::Deque::<u8, 256>::new();

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

    let rng = rand::rngs::SmallRng::seed_from_u64(1234);
    unsafe {
        let _ = RNG.insert(rng);
    };

    sprint!("Setup interrupts...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::TqFull, 6);
    setup_irq(Interrupt::TqNotFull, 6);
    setup_irq(Interrupt::Timer0Cmp, 5);
    setup_irq(Interrupt::MachineTimer, u8::MAX);
    setup_irq(Interrupt::TqId0, 1);
    setup_irq(Interrupt::TqId1, 1);
    setup_irq(Interrupt::TqId2, 1);
    setup_irq(Interrupt::TqId3, 1);
    setup_irq(Interrupt::TqId4, 1);
    setup_irq(Interrupt::TqId5, 1);
    setup_irq(Interrupt::TqId6, 1);
    setup_irq(Interrupt::TqId7, 1);
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

    // Init mtimer
    let mut mtimer = MTimer::instance().into_oneshot();

    // Test will end when MachineTimer fires
    mtimer.start(TEST_DURATION);

    // Setup a periodic timer for "the pusher"
    let mut t0 = Timer::init::<TIMER0_ADDR>().into_periodic();
    t0.set_period(Duration::micros(PUSH_PERIOD_US));
    t0.start();

    let _timer_q = TimerQueue::init();

    // This benchmark requires the main queue to be 256 deep
    //assert!(timer_q.capacity() >= Q_LEN);

    // Enable interrupts globally
    unsafe { riscv::interrupt::enable() };

    while !unsafe { TIMEOUT } {
        wfi();
    }

    // === TEST ENDS ===

    sprint!("Interrupt counts [");
    for v in unsafe { CNT } {
        sprint!("{}, ", v);
    }
    sprintln!("]");

    bsp::tb::signal_pass(Some(&mut serial));
    loop {}
}

#[interrupt]
fn TqFull() {
    sprintln!("IRQ:TqFull");
}

#[interrupt]
fn TqNotFull() {
    sprintln!("IRQ:TqNotFull");
}

/// Periodically inserts N tasks with randomized offsets into the queue.
///
/// Timer0Cmp needs to be nested and lower priority than "TqFull", otherwise we
/// will not be able to react to when the queue becomes overfull.
#[nested_interrupt]
fn Timer0Cmp() {
    sprintln!("IRQ:Timer0Cmp");
    for _ in 0..10 {
        unsafe { RNG.as_mut() }.map(|rng| {
            let irq_id = rng.next_u32() as u8 % 8;
            let ofs = rng.next_u64() % 1_000;

            let swq = unsafe { SW_PQ.as_mut().unwrap() };
            let bq = unsafe { BACKUP.as_mut().unwrap() };

            // SAFETY: none at all, this will break
            unsafe { abstract_insert(irq_id, ofs, swq, &mut FREE_HANDLES, bq) };
            //let counter = MTimer::instance().counter();
            /*sprintln!("  mtime={}", counter);
            sprintln!(
                "  sched'd irq {} ofs={} (abs~{})",
                irq_id,
                ofs,
                ofs + counter
            );*/
        });
    }
}

static mut CNT: [u32; 8] = [0; 8];

use paste::paste;
macro_rules! tq_handler {
    ($id:expr) => {
        paste! {
            #[interrupt]
            fn [<TqId $id>]() {
                /*
                sprintln!("IRQ:TqId{}", $id);
                let counter = MTimer::instance().counter();
                sprintln!("  mtime={}", counter);
                */

                // Safety: CNT is not shared during test run
                unsafe { CNT.get_unchecked_mut($id).add_assign(1) };
            }
        }
    };
}

tq_handler!(0);
tq_handler!(1);
tq_handler!(2);
tq_handler!(3);
tq_handler!(4);
tq_handler!(5);
tq_handler!(6);
tq_handler!(7);

/// Test timeout interrupt (per test-run)
#[interrupt]
unsafe fn MachineTimer() {
    sprintln!("IRQ:MachineTimer");
    unsafe { TIMEOUT = true };

    tear_irq(Interrupt::TqFull);
    tear_irq(Interrupt::TqNotFull);
    tear_irq(Interrupt::Timer0Cmp);
    tear_irq(Interrupt::MachineTimer);
    tear_irq(Interrupt::TqId0);
    tear_irq(Interrupt::TqId1);
    tear_irq(Interrupt::TqId2);
    tear_irq(Interrupt::TqId3);
    tear_irq(Interrupt::TqId4);
    tear_irq(Interrupt::TqId5);
    tear_irq(Interrupt::TqId6);
    tear_irq(Interrupt::TqId7);
}
