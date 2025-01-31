//! Blinks fast for a second, then enters interrupt handler that sets the LED on
//!
//! # Known issues
//!
//! * Running this example twice without reset causes exception with
//!   * $mcause = 0x38000002
//!   * $mepc = 0x22
#![no_main]
#![no_std]

use core::ptr;

use bsp::{
    clic::Clic,
    led::{led_off, led_on, led_toggle, Led},
    mmap::*,
    riscv,
    rt::entry,
    sprintln, tb,
    uart::ApbUart,
    write_u32, Interrupt, CPU_FREQ,
};
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

const MTIMER_IRQ: Interrupt = Interrupt::MachineTimer;

static mut LOCK: bool = true;

/// Example entry point
#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(bsp::CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Enable global interrupts
    unsafe { riscv::interrupt::enable() };

    setup_irq(MTIMER_IRQ);

    let prescaler = 0xf;

    // Set mtimecmp to something non-zero to produce a delayed interrupt
    write_u32(
        MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS,
        2 * (CPU_FREQ / prescaler),
    );

    // Enable timer [bit 0] & set prescaler [bits 20:8]
    write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, prescaler << 8 | 0b1);

    wait_on_lock();

    // No side-effects, reset to default state

    // Disable timer [bit 0], prescaler 0xf00
    write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0xf00);
    write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, 0);
    tear_irq(MTIMER_IRQ);
    riscv::interrupt::disable();

    tb::signal_pass(Some(&mut serial));
    loop {}
}

fn wait_on_lock() {
    use bsp::{asm_delay, led::Led, NOPS_PER_SEC};

    let ord = [Led::Ld3, Led::Ld2, Led::Ld3].windows(2);
    let delay = NOPS_PER_SEC / ord.len() as u32;
    for leds in ord.cycle() {
        if !unsafe { ptr::read_volatile(ptr::addr_of_mut!(LOCK)) } {
            break;
        }
        led_off(leds[0]);
        led_on(leds[1]);
        asm_delay(delay);
    }
}

#[export_name = "DefaultHandler"]
fn custom_interrupt_handler() {
    unsafe { Clic::ip(MTIMER_IRQ).unpend() };

    // Flip a led and unlock the lock
    led_toggle(Led::Ld0);
    unsafe { ptr::write_volatile(ptr::addr_of_mut!(LOCK), false) };
}
