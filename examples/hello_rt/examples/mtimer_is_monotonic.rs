//! Take measurements of mtimer and make sure they're monotonically increasing,
//! i.e., each measurement is bigger than the last.
#![no_main]
#![no_std]

use bsp::{asm_delay, mtimer::MTimer, rt::entry, sprintln, uart::*, CPU_FREQ, NOPS_PER_SEC};
use hello_rt::{print_example_name, UART_BAUD};

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Enable timer (bit 0) & set prescaler to 0xf (bits 20:8)
    let prescaler = 0xf;
    let mut mtimer = MTimer::en(prescaler);

    let mut p_mtime;
    let mut mtime = 0;

    loop {
        p_mtime = mtime;
        mtime = unsafe { mtimer.read() };
        sprintln!("mtime: {}", mtime);
        if mtime > p_mtime {
            #[cfg(feature = "rtl-tb")]
            bsp::tb::rtl_tb_signal_ok();
        } else {
            #[cfg(feature = "rtl-tb")]
            bsp::tb::rtl_tb_signal_fail();
            assert!(false, "mtime must increase monotonically");
        }
        asm_delay(NOPS_PER_SEC / 2);
    }
}
