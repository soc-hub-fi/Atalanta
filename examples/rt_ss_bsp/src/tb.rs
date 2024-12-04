//! Test bench utilities
//!
//! Let the tester & the sim know if the test case is ok or fail.

// The testbench utilities are typically called once per method. Therefore it
// makes sense to inline most functions to prefer saving on limited stack size.

use crate::{
    led::{led_off, led_on, Led},
    uart::uart_write,
};

pub const TEST_PASS_TAG: &str = "[PASSED]";
/// Partial OK
pub const TEST_OK_TAG: &str = "[OK]";
pub const TEST_FAIL_TAG: &str = "[FAILED]";

#[cfg(any(all(feature = "fpga", feature = "rt"), feature = "panic"))]
pub(crate) const DEFAULT_BAUD: u32 = if cfg!(feature = "rtl-tb") {
    3_000_000
} else {
    9600
};

/// Format a message and signal that a part of the test was OK
#[macro_export]
macro_rules! signal_partial_ok {
    ($($tt:tt)*) => {{
        use $crate::{sprint, tb::TEST_OK_TAG};
        sprint!("{} ", TEST_OK_TAG);
        sprintln!($($tt)*);
    }};
}
pub use signal_partial_ok;

/// Format a message and signal that a part of the test failed
#[macro_export]
macro_rules! signal_partial_fail {
    ($($tt:tt)*) => {{
        use $crate::{sprint, tb::TEST_FAIL_TAG};
        sprint!("{} ", TEST_FAIL_TAG);
        sprintln!($($tt)*);
    }};
}
pub use signal_partial_fail;

/// Signal that everything is alright and test case is considered passing
#[inline]
pub fn signal_pass(use_uart: bool) -> ! {
    if use_uart {
        uart_write(TEST_PASS_TAG);
        uart_write("\r\n");
    }

    match () {
        #[cfg(feature = "rtl-tb")]
        () => rtl_testbench_signal_ok(),
        #[cfg(not(feature = "rtl-tb"))]
        () => ok_blink(),
    }
}

/// Signal general failure
#[inline]
pub fn signal_fail(use_uart: bool) -> ! {
    if use_uart {
        uart_write(TEST_FAIL_TAG);
        uart_write("\r\n");
    }

    match () {
        #[cfg(feature = "rtl-tb")]
        () => rtl_testbench_signal_fail(),
        #[cfg(not(feature = "rtl-tb"))]
        () => fail_blink(),
    }
}

/// Signal that the test case is waiting for a timered event to happen
#[inline]
pub fn signal_wait() -> ! {
    match () {
        #[cfg(feature = "rtl-tb")]
        // No signaling required on sim
        () => loop {},
        #[cfg(not(feature = "rtl-tb"))]
        () => wait_blink(),
    }
}

#[cfg(feature = "rtl-tb")]
#[inline]
pub(crate) fn rtl_testbench_signal_fail() -> ! {
    // The RTL testbench convention is that if led 0 is high and led 1 is down,
    // the test case is considered failing so let's make sure we're matching
    // that first
    led_off(Led::Ld1);
    led_on(Led::Ld0);

    // We must end on a timeout for the testbench and therefore cannot do any
    // work after signaling failure
    loop {}
}

#[cfg(feature = "rtl-tb")]
#[inline]
fn rtl_testbench_signal_ok() -> ! {
    // The RTL testbench convention is that if leds [0, 1] are high the test
    // case is considered passing
    led_on(Led::Ld1);
    led_on(Led::Ld0);

    loop {}
}

/// Uses all 4 leds to represent the 4 LSBs of the exception code
///
/// Flashess all leds simultaneously and slowly
#[export_name = "ExceptionHandler"]
#[cfg(all(feature = "fpga", feature = "rt"))]
fn blink_exception(_trap_frame: &riscv_rt::TrapFrame) -> ! {
    use crate::{asm_delay, led::led_set, sprintln, uart::init_uart, NOPS_PER_SEC};

    // Initialize UART if not initialized
    if !unsafe { crate::uart::UART_IS_INIT } {
        init_uart(crate::CPU_FREQ, DEFAULT_BAUD);
    }

    uart_write(TEST_FAIL_TAG);
    uart_write("\r\n");

    let code = riscv::register::mcause::read().code();
    sprintln!("\r\nException: {}", code);

    loop {
        // Show 4 LSBs of the exception code on the leds (use GDB to read the rest)
        led_set(Led::Ld0, code & 0b1 == 0b1);
        led_set(Led::Ld1, code >> 1 & 0b1 == 0b1);
        led_set(Led::Ld2, code >> 2 & 0b1 == 0b1);
        led_set(Led::Ld3, code >> 3 & 0b1 == 0b1);

        asm_delay(NOPS_PER_SEC * 4 / 5);

        led_off(Led::Ld0);
        led_off(Led::Ld1);
        led_off(Led::Ld2);
        led_off(Led::Ld3);

        asm_delay(NOPS_PER_SEC / 5);
    }
}

#[cfg(all(feature = "fpga", feature = "panic"))]
pub(crate) fn blink_panic() -> ! {
    use crate::{asm_delay, led::Led::*, NOPS_PER_SEC};

    let ord = [Ld3, Ld1, Ld2, Ld0, Ld3].windows(2);
    let delay = NOPS_PER_SEC / ord.len() as u32;
    for leds in ord.cycle() {
        led_off(leds[0]);
        led_on(leds[1]);
        asm_delay(delay);
    }

    unreachable!()
}

/// Blinks leds 2 & 3, like a police
#[cfg(feature = "fpga")]
pub fn wait_blink() -> ! {
    use crate::{asm_delay, led::Led::*, NOPS_PER_SEC};

    led_off(Ld0);
    led_off(Ld1);

    let ord = [Ld3, Ld2, Ld3].windows(2);
    let delay = NOPS_PER_SEC / ord.len() as u32;
    for leds in ord.cycle() {
        led_off(leds[0]);
        led_on(leds[1]);
        asm_delay(delay);
    }

    unreachable!()
}

/// Flahes two leds on and off, fast
#[cfg(feature = "fpga")]
fn ok_blink() -> ! {
    use crate::{asm_delay, NOPS_PER_SEC};

    led_off(Led::Ld2);
    led_off(Led::Ld3);

    loop {
        led_on(Led::Ld0);
        led_on(Led::Ld1);
        asm_delay(NOPS_PER_SEC / 4);
        led_off(Led::Ld0);
        led_off(Led::Ld1);
        asm_delay(NOPS_PER_SEC / 4);
    }
}

/// Flashes all leds on and off, slow
#[cfg(feature = "fpga")]
fn fail_blink() -> ! {
    match () {
        #[cfg(feature = "rtl-tb")]
        () => rtl_testbench_signal_fail(),
        #[cfg(not(feature = "rtl-tb"))]
        () => {
            use crate::{asm_delay, NOPS_PER_SEC};
            loop {
                led_on(Led::Ld0);
                led_on(Led::Ld1);
                led_on(Led::Ld2);
                led_on(Led::Ld3);
                asm_delay(NOPS_PER_SEC);
                led_off(Led::Ld0);
                led_off(Led::Ld1);
                led_off(Led::Ld2);
                led_off(Led::Ld3);
                asm_delay(NOPS_PER_SEC);
            }
        }
    }
}
