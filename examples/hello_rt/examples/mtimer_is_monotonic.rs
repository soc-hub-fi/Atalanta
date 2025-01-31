//! Take measurements of mtimer and make sure they're monotonically increasing,
//! i.e., each measurement is bigger than the last.
#![no_main]
#![no_std]
#![allow(static_mut_refs)]
#![allow(non_snake_case)]

use bsp::{
    clic::Clic,
    mtimer::MTimer,
    riscv::{self, asm::wfi},
    rt::{entry, interrupt},
    sprintln,
    uart::ApbUart,
    Interrupt, CPU_FREQ, NOPS_PER_SEC,
};
use heapless::Vec;
use hello_rt::{print_example_name, setup_irq, tear_irq, UART_BAUD};

const INTERVAL: u64 = if cfg!(feature = "rtl-tb") {
    0x100
} else {
    NOPS_PER_SEC as u64 / 2
};

static mut SAMPLES: Vec<u64, 8> = Vec::<u64, 8>::new();
static mut STOP: bool = false;

#[entry]
fn main() -> ! {
    let mut serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Set a timer to trigger an interrupt every `ÌNTERVAL`
    let mut mtimer = MTimer::instance();
    setup_irq(Interrupt::MachineTimer);
    unsafe {
        let counter = mtimer.counter();
        mtimer.set_cmp(counter + INTERVAL);
        riscv::interrupt::enable();
    }
    mtimer.enable();

    while !unsafe { STOP } {
        wfi();
    }

    // Make sure the timer is monotonically increasing
    assert!(
        unsafe { SAMPLES.windows(2).all(|win| win[0] < win[1]) },
        "timer must increase monotonically"
    );
    // Clean up
    tear_irq(Interrupt::MachineTimer);

    bsp::tb::signal_pass(Some(&mut serial));
    loop {}
}

#[interrupt]
unsafe fn MachineTimer() {
    let mut mtimer = MTimer::instance();
    let sample = mtimer.counter();
    sprintln!("mtime: {}", sample);
    SAMPLES.push(sample).unwrap_unchecked();
    if SAMPLES.len() == SAMPLES.capacity() {
        STOP = true;
        return;
    }
    mtimer.set_cmp(sample + INTERVAL);
}
