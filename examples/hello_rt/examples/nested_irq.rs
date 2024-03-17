//! Tests that nested interrupts work as expected
//!
//! N.b. this test is unsound as is currently relies on the UB of CLIC that
//! interrupts get dispatched in the order of arrival instead of being
//! arbitrated with priority.
#![no_main]
#![no_std]

use core::{arch::asm, ptr};

use hello_rt::{
    asm_delay,
    clic::CLIC,
    print_example_name, sprint, sprintln,
    tb::{signal_fail, signal_ok},
    uart::init_uart,
};
use riscv_peripheral::clic::{
    intattr::{Polarity, Trig},
    InterruptNumber,
};
use riscv_rt::entry;

#[derive(Clone, Copy, PartialEq)]
#[repr(u16)]
pub enum Irq {
    Lo = 16,
    Hi = 17,
}

unsafe impl InterruptNumber for Irq {
    const MAX_INTERRUPT_NUMBER: u16 = 255;

    fn number(self) -> u16 {
        self as u16
    }

    fn from_number(value: u16) -> Result<Self, u16> {
        match value {
            16 => Ok(Self::Lo),
            17 => Ok(Self::Hi),
            _ => Err(value),
        }
    }
}

static mut LOCK: u8 = 0;

#[entry]
fn main() -> ! {
    init_uart(hello_rt::CPU_FREQ, 9600);
    print_example_name!();

    // Set level bits to 8
    CLIC::smclicconfig().set_mnlbits(8);

    setup_irq(Irq::Lo, 0x1);
    setup_irq(Irq::Hi, 0x2);

    unsafe {
        // Raise interrupt threshold in RT-Ibex before enabling interrupts
        // mintthresh = 0x347
        asm!("csrw 0x347, {0}", in(reg) 0xff);

        // Enable global interrupts
        riscv::interrupt::enable();

        // No interrupt will fire yet
        CLIC::ip(Irq::Lo).pend();
        CLIC::ip(Irq::Hi).pend();

        // Lower interrupt threshold in RT-Ibex. Interrupts should fire.
        sprintln!("lowering threshold");
        asm!("csrw 0x347, {0}", in(reg) 0x0);

        asm_delay(1000);
    }

    if unsafe { ptr::read_volatile(ptr::addr_of_mut!(LOCK)) } == 2u8 {
        riscv::interrupt::disable();
        tear_irq(Irq::Lo);
        tear_irq(Irq::Hi);
        signal_ok(true)
    } else {
        riscv::interrupt::disable();
        tear_irq(Irq::Lo);
        tear_irq(Irq::Hi);
        signal_fail(true)
    }
}

/// # Safety
///
/// - Do not call this function inside a critical section.
/// - This method is assumed to be called within an interrupt handler.
/// - Make sure to clear the interrupt flag that caused the interrupt before calling
/// this method. Otherwise, the interrupt will be re-triggered before executing `f`.
#[inline]
pub unsafe fn nested<F, R>(f: F) -> R
where
    F: FnOnce() -> R,
{
    asm!(
        "addi sp, sp, -(4 * 2)",
        "csrr t0, mcause",
        "csrr t1, mepc",
        "sw t0, 0(sp)",
        "sw t1, 4(sp)",
    );

    // enable interrupts to allow nested interrupts
    riscv::interrupt::enable();

    let r: R = f();

    riscv::interrupt::disable();

    asm!(
        "lw t0, 0(sp)",
        "lw t1, 4(sp)",
        "csrw mcause, t0",
        "csrw mepc, t1",
        "addi sp, sp, (4 * 2)",
    );

    r
}

#[export_name = "DefaultHandler"]
fn interrupt_handler() {
    let irq_n = (riscv::register::mcause::read().bits() & 0xfff) as u16;
    let irq = unsafe { Irq::from_number(irq_n).unwrap_unchecked() };
    unsafe { CLIC::ip(irq).unpend() };
    if irq_n == Irq::Lo.number() {
        sprintln!("IRQ enter: lo");
    } else if irq_n == Irq::Hi.number() {
        sprintln!("IRQ enter: hi");
    }

    if irq == Irq::Lo {
        sprintln!("lo: waiting for hi to set the lock...");

        unsafe { nested(|| while ptr::read_volatile(ptr::addr_of_mut!(LOCK)) == 0u8 {}) }
        sprintln!("lo: lock value updated, continuing");

        unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), 2u8) };
    } else if irq == Irq::Hi {
        unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), 1u8) }
        sprintln!("hi: lock value set");
    }

    if irq_n == Irq::Lo.number() {
        sprintln!("IRQ leave: lo");
    } else if irq_n == Irq::Hi.number() {
        sprintln!("IRQ leave: hi");
    }

    asm_delay(100);
}

#[inline]
fn setup_irq(irq: Irq, prio: u8) {
    sprintln!("set up IRQ");
    CLIC::attr(irq).set_trig(Trig::Edge);
    CLIC::attr(irq).set_polarity(Polarity::Pos);
    CLIC::attr(irq).set_shv(true);
    CLIC::ctl(irq).set_priority(prio);
    unsafe { CLIC::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
#[inline]
fn tear_irq(irq: Irq) {
    sprintln!("tear down IRQ");
    CLIC::ie(irq).disable();
    CLIC::ctl(irq).set_priority(0x0);
    CLIC::attr(irq).set_shv(false);
    CLIC::attr(irq).set_trig(Trig::Level);
    CLIC::attr(irq).set_polarity(Polarity::Pos);
}
