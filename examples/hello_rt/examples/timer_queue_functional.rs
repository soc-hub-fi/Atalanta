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
    mtimer::MTimer, asm_delay,
    clic::Clic, nested_interrupt, riscv, rt::entry, sprint, sprintln, timer_queue::TimerQueue,
    uart::*, Interrupt, CPU_FREQ,
};
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

//static mut IS_FULL: bool = false;
static mut ONE_FIRED: bool = false;
static mut FIVE_FIRED: bool = false;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    sprintln!("Setup CLIC...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    setup_irq(Interrupt::TqId1);
    setup_irq(Interrupt::TqId5);
    sprintln!("done");

    let timer_q = TimerQueue::init();
    let mut mtimer = MTimer::instance();
    mtimer.enable();

    // Push 8 values. Should result in 'full' interrupt.
    let mut handles = [0; 8];
    for idx in 0..8 {
        handles[idx] = timer_q.push_abs(8000 + (idx as u64)*0, idx as u8);
        sprintln!("Push payload {}", idx as u8);
    }

    asm_delay(10);

    sprintln!("Top: {}", timer_q.top_idx());

    sprintln!("Tear down");

    tear_irq(Interrupt::TqId1);
    tear_irq(Interrupt::TqId5);
    riscv::interrupt::disable();

    bsp::tb::signal_pass(Some(&mut serial));

    loop {}
}

#[nested_interrupt]
fn TqId1() {
    //sprintln!("TQ is full (irq)");
    unsafe { ONE_FIRED = true };
}

#[nested_interrupt]
fn TqId5() {
    //sprintln!("TQ is not full (irq)");
    //unsafe { IS_FULL = false };
    unsafe { FIVE_FIRED = true };
}
