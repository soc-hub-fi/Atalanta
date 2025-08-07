//! UART pin map, incl. PYNQ-Z1:
//!
//! | Host  | Device    | PYNQ-Z1 |
//! | :-:   | :-:       | :-:     |
//! | TX    | RX        | IO12    |
//! | RX    | TX        | IO13    |
#![no_main]
#![no_std]
#![allow(non_snake_case)]

use bsp::{
    clic::Clic,
    nested_interrupt, riscv,
    rt::entry,
    sprint, sprintln,
    timer_queue::{Entry, TimerQueue},
    uart::*,
    Interrupt, CPU_FREQ,
};
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

static mut IS_FULL: bool = false;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    sprintln!("Setup CLIC...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    sprint!("  ");
    setup_irq(Interrupt::TqFull);
    sprint!("  ");
    setup_irq(Interrupt::TqNotFull);
    sprintln!("done");

    let mut timer_q = TimerQueue::init();

    // Push 8 values. Should result in 'full' interrupt.
    let mut indices = [0; 8];
    for idx in 0..8 {
        let ts = idx as u64 + 1;
        let pl = (8 - idx as u8) + 1;
        sprintln!("Push ts={}, pl={}...", ts, pl);
        indices[idx] = timer_q.push_abs(Entry::new(ts, pl));
        sprintln!("idx <- {} (ts={}, pl={})", indices[idx], ts, pl);
    }

    // 8 values => queue is full
    assert!(unsafe { IS_FULL });

    sprintln!("Drop idx={}", indices[0]);
    timer_q.drop(indices[0]);

    // 7 values => queue is not full
    assert!(unsafe { !IS_FULL });

    sprintln!("Top: idx={}", timer_q.top_idx());

    tear_irq(Interrupt::TqFull);
    tear_irq(Interrupt::TqNotFull);
    riscv::interrupt::disable();

    bsp::tb::signal_pass(Some(&mut serial));

    loop {}
}

#[nested_interrupt]
fn TqFull() {
    sprintln!("IRQ: TQ is full");
    unsafe { IS_FULL = true };
}

#[nested_interrupt]
fn TqNotFull() {
    sprintln!("IRQ: TQ is not full");
    unsafe { IS_FULL = false };
}
