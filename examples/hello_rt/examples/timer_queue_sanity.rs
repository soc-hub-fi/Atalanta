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
    asm_delay, clic::Clic, interrupt, mmap::timer_queue::TIMER_QUEUE, riscv, rt::entry, sprint,
    sprintln, uart::*, write_u32p, Interrupt, CPU_FREQ,
};
use hello_rt::{function, print_example_name, setup_irq, tear_irq, UART_BAUD};

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    sprintln!("Setup CLIC...");
    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    setup_irq(Interrupt::TqId0);
    sprintln!("done");

    sprintln!("Writing 1 to TIMER_QUEUE.pd_ctrl...");
    write_u32p(unsafe { &mut (*TIMER_QUEUE).pd_ctrl as *mut u32 }, 0b1 << 0);
    sprintln!("done");

    asm_delay(10);

    tear_irq(Interrupt::TqId0);
    riscv::interrupt::disable();

    #[cfg(feature = "rtl-tb")]
    bsp::tb::rtl_tb_signal_fail();

    loop {}
}

#[interrupt]
fn TqId0() {
    sprintln!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);

    tear_irq(Interrupt::TqId0);
    riscv::interrupt::disable();

    #[cfg(feature = "rtl-tb")]
    bsp::tb::rtl_tb_signal_ok();

    sprintln!("leave {}", function!());
}
