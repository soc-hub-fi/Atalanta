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

use core::arch::{asm, global_asm};

use bsp::{
    clic::{Clic, InterruptNumber},
    interrupt,
    mmap::{CFG_BASE, PERIPH_CLK_DIV_OFS},
    mtimer::MTimer,
    register::mcycle,
    riscv::{
        self,
        asm::{nop, wfi},
    },
    rt::entry,
    sprint, sprintln,
    uart::*,
    write_u32, Interrupt, CPU_FREQ,
};
#[cfg(any(feature = "use-bheap", feature = "use-imap"))]
use pqbench::Dispatch;
use pqbench::{
    disable_pcs, enable_pcs, print_example_name, setup_irq, tear_irq, PQueue, UART_BAUD,
};

const PERIPH_CLK_DIV: u64 = 1;

/// Main queue length
#[cfg(not(all(feature = "use-hwq", not(feature = "virtq"))))]
const Q_LEN: usize = if cfg!(not(feature = "virtq")) { 256 } else { 8 };

/// Backup queue len (has to be a power of 2)
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
const B_LEN: usize = 256;

#[cfg(all(feature = "use-hwq", not(feature = "virtq")))]
type TqT = bsp::timer_queue::TimerQueue;
#[cfg(all(feature = "use-hwq", feature = "virtq"))]
type TqT = pqbench::VQueue<Q_LEN, B_LEN>;
#[cfg(feature = "use-bheap")]
type TqT = pqbench::BHeap<Q_LEN>;
#[cfg(feature = "use-imap")]
type TqT = pqbench::IMap<Q_LEN>;

static mut SHARED_TQ: Option<TqT> = None;
static mut DISPATCHED: usize = 0;

fn prof<F, O>(op_ident: &str, f: F) -> O
where
    F: FnOnce() -> O,
{
    let mc0 = mcycle::read64();
    unsafe { asm!("fence.i") };
    let output = f();
    unsafe { asm!("fence.i") };
    let mc1 = mcycle::read64();
    sprintln!("{} took {} cc ({} - {})", op_ident, mc1 - mc0, mc1, mc0);

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

    sprint!("Setup interrupts...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    //setup_irq(Interrupt::TqFull, 6);
    // Refill hardware queue at low priority
    //setup_irq(Interrupt::TqNotFull, 1);
    setup_irq(Interrupt::MachineTimer, u8::MAX);
    setup_irq(Interrupt::TqId0, 2);
    enable_pcs(Interrupt::TqId0);
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
            let tq = bsp::timer_queue::TimerQueue::init();
            // This benchmark requires the main queue to be 256 deep
            assert!(tq.capacity() >= 256);
            tq
        }
        #[cfg(all(feature = "use-hwq", feature = "virtq"))]
        () => {
            sprintln!("Feature: use-hwq + virtq");
            #[cfg(feature = "virtq")]
            sprintln!("Queue is virtualized w/ a backup queue of length {}", B_LEN);
            let tq = pqbench::VQueue::default();
            // This benchmark requires the main queue to be 8 deep
            assert_eq!(tq.tq.capacity(), 8);
            tq
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
    let timer_q = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };

    const INS_CNT: usize = 12;

    // Benchmark insert
    let mut handles = heapless::Vec::<u8, 256>::new();
    let mut mtimer = MTimer::instance();
    let mtimer_state = mtimer.is_enabled();
    mtimer.disable();
    unsafe { mtimer.set_counter(0) };
    for n in 0..INS_CNT {
        let mut s = heapless::String::<256>::new();
        unsafe { bsp::write!(s, "ins {}", n).unwrap_unchecked() };
        let h = prof(&s, || {
            timer_q.enqueue_rel(bsp::timer_queue::Entry::new((0b1 << 24) - 1, 0))
        });
        unsafe { handles.push(h).unwrap_unchecked() };
    }

    // Benchmark drop
    for h in handles {
        let mut s = heapless::String::<256>::new();
        unsafe { bsp::write!(s, "drp {}", h).unwrap_unchecked() };
        prof(&s, || {
            timer_q.drop(h);
        });
    }

    // Unpend no-op interrupts caused by the test case
    unsafe {
        Clic::ip(Interrupt::TqFull).unpend();
        Clic::ip(Interrupt::TqNotFull).unpend();
    }

    if mtimer_state {
        mtimer.enable()
    };
    // Enable interrupts globally
    sprintln!("interrupt::enable");
    unsafe { riscv::interrupt::enable() };

    // Benchmark dispatch
    for n in 0..INS_CNT {
        let mut s = heapless::String::<256>::new();
        unsafe { bsp::write!(s, "dsp w/ {} prior elems", n).unwrap_unchecked() };
        unsafe { DISPATCHED = 0 };
        // Enqueue an extra event to cause load for dispatcher
        if n > 0 {
            timer_q.enqueue_abs(bsp::timer_queue::Entry::new((0b1 << 24) - 1, 0));
        }
        prof(&s, || {
            timer_q.enqueue_rel(bsp::timer_queue::Entry::new(0, 0));
            while !unsafe { DISPATCHED != 0 } {
                nop();
            }
        });
    }

    tear_irq(Interrupt::TqFull);
    tear_irq(Interrupt::TqNotFull);
    tear_irq(Interrupt::TqId0);
    tear_irq(Interrupt::MachineTimer);
    disable_pcs(Interrupt::TqId0);

    bsp::tb::signal_pass(Some(&mut serial));
    loop {
        wfi()
    }
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
        unsafe { tq.free_handles.push_back(f.1).unwrap_unchecked() };
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

// PCS interrupt in assembly (TqId0)
global_asm!(
    r#"
.section .trap, "ax"
.align 4
.global _start_TqId0_trap
_start_TqId0_trap:
    // Increment DISPATCHED
    lla     a0, {DISPATCHED}
    lw      a1, 0(a0)
    addi    a1, a1, 1
    sw      a1, 0(a0)

    mret
"#, DISPATCHED = sym DISPATCHED
);

// MTimer acts as dispatcher for the most urgent entry in the software queue
#[cfg(not(feature = "use-hwq"))]
#[interrupt]
fn MachineTimer() {
    //sprintln!("IRQ:MachineTimer");

    let tq = unsafe { SHARED_TQ.as_mut().unwrap_unchecked() };
    tq.dispatch();
}

#[export_name = "DefaultHandler"]
fn default_handler() {
    // 8 LSBs of mcause must match interrupt id
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!("IRQ:DefaultHandler {} ({:?})", irq_code, unsafe {
        bsp::Interrupt::from_number(irq_code).unwrap_unchecked()
    });
}
