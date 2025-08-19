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
    uart::*,
    write_u32, Interrupt, CPU_FREQ,
};
use pqbench::{print_example_name, setup_irq, tear_irq, PQueue, UART_BAUD};
use rand::{RngCore, SeedableRng};

const PERIPH_CLK_DIV: u64 = 1;
const TEST_DURATION: mtimer::Duration = mtimer::Duration::micros(500);
const PUSH_PERIOD_US: u32 = 100;

/// Main queue length
const Q_LEN: usize = if cfg!(not(feature = "virtq")) { 256 } else { 8 };

static mut TIMEOUT: bool = false;
static mut RNG: Option<rand::rngs::SmallRng> = None;

#[cfg(all(feature = "use-hwq", not(feature = "virtq")))]
type TqT = bsp::timer_queue::TimerQueue;
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
type TqT = pqbench::VQueue<Q_LEN, B_LEN>;
#[cfg(feature = "use-bheap")]
type TqT = pqbench::BHeap<Q_LEN>;
#[cfg(feature = "use-imap")]
type TqT = pqbench::IMap<Q_LEN>;

static mut SHARED_TQ: Option<TqT> = None;

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

    // mtimer is required for dispatch test
    let mut mtimer = MTimer::instance();
    mtimer.set_cmp(u64::MAX);
    sprintln!("Start mtimer");
    mtimer.enable();

    let timer_q = match () {
        #[cfg(all(feature = "use-hwq", not(feature = "virtq")))]
        () => {
            sprintln!("Feature: use-hwq");
            bsp::timer_queue::TimerQueue::init()
        }
        #[cfg(all(feature = "use-hwq", feature = "virtq"))]
        () => {
            sprintln!("Feature: use-hwq + virtq");
            #[cfg(feature = "virtq")]
            sprintln!(
                "Queue is virtualized with a backup queue of length {}",
                B_LEN
            );
            pqbench::VQueue::default()
        }
        #[cfg(feature = "use-bheap")]
        () => {
            sprintln!("Feature: use-bheap");
            pqbench::BHeap::new(mtimer)
        }
        #[cfg(feature = "use-imap")]
        () => {
            sprintln!("Feature: use-imap");
            pqbench::IMap::new(mtimer)
        }
    };

    unsafe {
        let _ = SHARED_TQ.insert(timer_q);
    }
    let _timer_q = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };

    // Init mtimer
    let mut mtimer = MTimer::instance().into_oneshot();

    // Test will end when MachineTimer fires
    mtimer.start(TEST_DURATION);

    // Setup a periodic timer for "the pusher"
    let mut t0 = Timer::init::<TIMER0_ADDR>().into_periodic();
    t0.set_period(Duration::micros(PUSH_PERIOD_US));
    t0.start();

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
    loop {
        wfi();
    }
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
        if let Some(rng) = unsafe { RNG.as_mut() } {
            let irq_id = rng.next_u32() as u8 % 8;
            let ofs = rng.next_u64() % 1_000;

            let tq = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };
            // SAFETY: none at all, this will break
            tq.enqueue_rel(bsp::timer_queue::Entry::new(ofs, irq_id));
            //let counter = MTimer::instance().counter();
            /*sprintln!("  mtime={}", counter);
            sprintln!(
                "  sched'd irq {} ofs={} (abs~{})",
                irq_id,
                ofs,
                ofs + counter
            );*/
        };
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
