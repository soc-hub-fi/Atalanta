//! Common software for testing RT-Ibex, Atalanta, AnTiQ, etc.
#![no_std]

pub mod clic;
#[cfg(not(feature = "ufmt"))]
mod core_sprint;
pub mod gpio;
mod interrupt;
pub mod led;
pub mod mmap;
pub mod mtimer;
pub mod register;
pub mod tb;
pub mod timer_group;
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

pub use embedded_io;
pub use fugit;
pub use interrupt::{nested, Interrupt};
pub use riscv;
#[cfg(feature = "rt")]
pub use riscv_rt::{self as rt, interrupt};
#[cfg(feature = "ufmt")]
pub use ufmt;

// Generate the `_continue_nested_trap` symbol
#[cfg(feature = "nest-continue")]
atalanta_bsp_macros::generate_continue_nested_trap!();

// Re-export macros for nested interrupts
pub use atalanta_bsp_macros::{
    generate_continue_nested_trap, generate_nested_trap_entry, generate_pcs_trap_entry,
    nested_interrupt,
};

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

/// Reads the masked bits from the register
///
/// # Safety
///
/// Unaligned reads may fail to produce expected results on rt-ss.
#[inline(always)]
pub unsafe fn read_u8_masked(addr: usize, mask: u8) -> u8 {
    core::ptr::read_volatile(addr as *const u8) & mask
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
pub fn read_u32p(ptr: *const u32) -> u32 {
    unsafe { core::ptr::read_volatile(ptr) }
}

#[inline(always)]
pub fn write_u32(addr: usize, val: u32) {
    write_u32p(addr as *mut _, val)
}

#[inline(always)]
pub fn write_u32p(ptr: *mut u32, val: u32) {
    unsafe { core::ptr::write_volatile(ptr, val) }
}

#[inline(always)]
pub fn modify_u32(addr: usize, val: u32, mask: u32, bit_pos: usize) {
    let mut tmp = read_u32(addr);
    tmp &= !(mask << bit_pos); // Clear bitfields
    write_u32(addr, tmp | (val << bit_pos));
}

#[inline(always)]
pub fn mask_u32(addr: usize, mask: u32) {
    mask_u32p(addr as *mut u32, mask)
}

#[inline(always)]
pub fn mask_u32p(ptr: *mut u32, mask: u32) {
    let r = unsafe { core::ptr::read_volatile(ptr) };
    unsafe { core::ptr::write_volatile(ptr, r | mask) }
}

/// Unmasks specified bits from given register
#[inline(always)]
pub fn unmask_u32(addr: usize, unmask: u32) {
    unmask_u32p(addr as *mut _, unmask);
}

/// Unmasks specified bits from given register
#[inline(always)]
pub fn unmask_u32p(ptr: *mut u32, unmask: u32) {
    let r = unsafe { core::ptr::read_volatile(ptr) };
    unsafe { core::ptr::write_volatile(ptr as *mut _, r & !unmask) }
}

#[inline(always)]
pub fn toggle_u32(addr: usize, toggle_bits: u32) {
    let mut r = read_u32(addr);
    r ^= toggle_bits;
    write_u32(addr, r);
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
///
/// # Safety
///
/// Unaligned writes may fail to produce expected results on RISC-V.
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
        () => {
            tb::rtl_tb_signal_fail();
            loop {}
        }
        #[cfg(not(feature = "rtl-tb"))]
        () => tb::blink_panic(),
    }
}
