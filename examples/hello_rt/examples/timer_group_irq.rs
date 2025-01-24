//! Take measurements of mtimer and make sure they're monotonically increasing,
//! i.e., each measurement is bigger than the last.
#![no_main]
#![no_std]

use bsp::{
    asm_delay,
    rt::entry,
    sprintln,
    timer_group::{Timer0, Timer1, Timer2, Timer3},
    uart::*,
    CPU_FREQ, NOPS_PER_SEC,
};
use hello_rt::{print_example_name, UART_BAUD};

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    let mut timers = (
        Timer0::init(),
        Timer1::init(),
        Timer2::init(),
        Timer3::init(),
    );
    timers.0.enable_with_prescaler(0);
    timers.1.enable_with_prescaler(1);
    timers.2.enable_with_prescaler(2);
    timers.3.enable_with_prescaler(3);

    loop {
        let time0 = timers.0.counter();
        let time1 = timers.1.counter();
        let time2 = timers.2.counter();
        let time3 = timers.3.counter();
        sprintln!(
            "times:\r\n  {}\r\n  {}\r\n  {}\r\n  {}",
            time0,
            time1,
            time2,
            time3
        );
        asm_delay(NOPS_PER_SEC);
    }
}
