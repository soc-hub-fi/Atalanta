//! Common software for testing RT-Ibex, Atalanta, AnTiQ, etc.
#![no_std]

pub mod clic;
#[cfg(not(feature = "ufmt"))]
mod core_sprint;
pub mod interrupt;
pub mod led;
pub mod mmap;
pub mod tb;
#[cfg(feature = "rt")]
mod trap;
pub mod uart;
#[cfg(feature = "ufmt")]
mod ufmt_debug;
#[cfg(feature = "ufmt")]
mod ufmt_sprint;

#[cfg(not(any(feature = "fpga", feature = "rtl-tb")))]
compile_error!(
    "Select one of -Ffpga -Frtl-tb, BSP supports FPGA and RTL testbench implementations only"
);

pub use interrupt::Interrupt;
pub use riscv;
#[cfg(feature = "rt")]
pub use riscv_rt as rt;
#[cfg(feature = "ufmt")]
pub use ufmt;

#[cfg(riscve)]
pub use rt_ss_bsp_macros::nested_interrupt_riscv32e as nested_interrupt;

#[cfg(riscvi)]
pub use rt_ss_bsp_macros::nested_interrupt_riscv32i as nested_interrupt;

use core::arch::asm;

/// Placeholder for RTIC
pub struct Peripherals {}

impl Peripherals {
    pub unsafe fn steal() -> Self {
        Self {}
    }
}

pub const CPU_FREQ: u32 = match () {
    #[cfg(feature = "rtl-tb")]
    () => 100_000_000,
    #[cfg(not(feature = "rtl-tb"))]
    () => 30_000_000,
};
// Experimentally found value for how to adjust for real-time
const fn nop_mult() -> u32 {
    match () {
        #[cfg(debug_assertions)]
        () => 60 / 12,
        #[cfg(not(debug_assertions))]
        () => 60 / 13,
    }
}
pub const NOPS_PER_SEC: u32 = CPU_FREQ / nop_mult();

pub fn asm_delay(t: u32) {
    for _ in 0..t {
        unsafe { asm!("nop") }
    }
}

/// # Safety
///
/// Unaligned reads may fail to produce expected results on rt-ss.
#[inline(always)]
pub unsafe fn read_u8(addr: usize) -> u8 {
    core::ptr::read_volatile(addr as *const _)
}

/// # Safety
///
/// Unaligned writes may fail to produce expected results on rt-ss.
#[inline(always)]
pub unsafe fn write_u8(addr: usize, val: u8) {
    core::ptr::write_volatile(addr as *mut _, val)
}

#[inline(always)]
pub fn read_u32(addr: usize) -> u32 {
    unsafe { core::ptr::read_volatile(addr as *const _) }
}

#[inline(always)]
pub fn write_u32(addr: usize, val: u32) {
    unsafe {
        core::ptr::write_volatile(addr as *mut _, val);
    }
}

#[inline(always)]
pub fn modify_u32(addr: usize, val: u32, mask: u32, bit_pos: usize) {
    let mut tmp = read_u32(addr);
    tmp &= !(mask << bit_pos); // Clear bitfields
    write_u32(addr, tmp | (val << bit_pos));
}

/// # Safety
///
/// Unaligned writes may fail to produce expected results on RISC-V.
#[inline(always)]
pub fn mask_u8(addr: usize, mask: u8) {
    let r = unsafe { core::ptr::read_volatile(addr as *const u8) };
    unsafe { core::ptr::write_volatile(addr as *mut _, r | mask) }
}

/// Unmasks specified bits from given register
#[inline(always)]
pub fn unmask_u8(addr: usize, unmask: u8) {
    let r = unsafe { core::ptr::read_volatile(addr as *const u8) };
    unsafe { core::ptr::write_volatile(addr as *mut _, r & !unmask) }
}

/// Blinks the leds fast in a confused fashion (3 -> 1 -> 2 -> 0 -> 3)
#[cfg(feature = "panic")]
#[panic_handler]
#[allow(unused_variables)]
fn panic_handler(info: &core::panic::PanicInfo) -> ! {
    // Initialize UART if not initialized
    if !unsafe { crate::uart::UART_IS_INIT } {
        crate::uart::ApbUart::init(crate::CPU_FREQ, crate::tb::DEFAULT_BAUD);
    }

    #[cfg(not(feature = "ufmt"))]
    sprintln!("{}", info);
    #[cfg(feature = "ufmt")]
    sprintln!("panic occurred");

    match () {
        #[cfg(feature = "rtl-tb")]
        () => tb::rtl_testbench_signal_fail(),
        #[cfg(not(feature = "rtl-tb"))]
        () => tb::blink_panic(),
    }
}

/// Print the name of the current file, i.e., test name.
///
/// This must be a macro to make sure core::file matches the file this is
/// invoked in.
#[macro_export]
macro_rules! print_example_name {
    () => {
        sprintln!("[{}]", core::file!());
    };
}
