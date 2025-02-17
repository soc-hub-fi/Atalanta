//! Tests that nested interrupts work as expected
#![no_main]
#![no_std]
#![allow(non_snake_case)]

use core::ptr;

use bsp::{
    clic::{
        intattr::{Polarity, Trig},
        Clic,
    },
    nested_interrupt, riscv,
    rt::entry,
    sprint, sprintln,
    tb::{signal_fail, signal_pass},
    uart::ApbUart,
    Interrupt,
};
use hello_rt::{function, print_example_name, tear_irq, UART_BAUD};

static mut LOCK: u8 = 0;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(bsp::CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    setup_irq(Interrupt::Dma0, 0x1);
    setup_irq(Interrupt::Dma1, 0x2);

    unsafe {
        // Raise interrupt threshold in RT-Ibex before enabling interrupts
        sprintln!("mintthresh <- 0xff");
        bsp::register::mintthresh::write(0xff.into());

        // Enable global interrupts
        riscv::interrupt::enable();

        // No interrupt will fire yet
        sprintln!("lo::pend");
        Clic::ip(Interrupt::Dma0).pend();

        // Lower interrupt threshold in RT-Ibex. Interrupts should fire.
        sprintln!("mintthresh <- 0x0");
        bsp::register::mintthresh::write(0x0.into());
    }

    while unsafe { ptr::read_volatile(ptr::addr_of_mut!(LOCK)) } != 2u8 {}
    riscv::interrupt::disable();
    tear_irq(Interrupt::Dma0);
    tear_irq(Interrupt::Dma1);

    if unsafe { ptr::read_volatile(ptr::addr_of_mut!(LOCK)) } == 2u8 {
        signal_pass(Some(&mut serial))
    } else {
        sprintln!("failure: lock value was {}", unsafe { LOCK });
        signal_fail(Some(&mut serial))
    }
    loop {}
}

#[nested_interrupt]
fn Dma0() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);

    unsafe {
        sprintln!("lo: enter");

        sprintln!("lo: waiting for hi to set lock");
        sprintln!("hi::pend");
        Clic::ip(Interrupt::Dma1).pend();
        while ptr::read_volatile(ptr::addr_of_mut!(LOCK)) == 0u8 {}
        sprintln!("lo: lock has updated, continuing");

        ptr::write_volatile(ptr::addr_of_mut!(LOCK), 2u8);

        sprintln!("lo: leave");
    }
}

#[nested_interrupt]
fn Dma1() {
    sprint!("enter {}", function!());
    let irq_code = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    sprintln!(" code: {}", irq_code);

    sprintln!("hi: enter");
    unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), 1u8) }
    sprintln!("hi: lock value set");
    sprintln!("hi: leave");
}

#[inline]
fn setup_irq(irq: Interrupt, level: u8) {
    sprintln!("set up IRQ");
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}
