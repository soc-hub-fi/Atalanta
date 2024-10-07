#![no_std]

use core::arch::{asm, global_asm};
use core::panic::PanicInfo;
use core::ptr;

pub const CPU_FREQ: u32 = match () {
    #[cfg(feature = "rtl-tb")]
    () => 100_000_000,
    #[cfg(feature = "fpga")]
    () => 40_000_000,
};
// Experimentally found value for how to adjust for real-time
const fn nop_mult() -> u32 {
    match () {
        #[cfg(debug_assertions)]
        () => 60 / 1,
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

#[inline(always)]
pub fn read_u8(addr: usize) -> u8 {
    unsafe { ptr::read_volatile(addr as *const _) }
}

#[inline(always)]
pub fn read_u32(addr: usize) -> u32 {
    unsafe { ptr::read_volatile(addr as *const _) }
}

#[inline(always)]
pub fn write_u8(addr: usize, val: u8) {
    unsafe { ptr::write_volatile(addr as *mut _, val) };
}

#[inline(always)]
pub fn write_u32(addr: usize, val: u32) {
    unsafe {
        ptr::write_volatile(addr as *mut _, val);
    }
}

#[panic_handler]
fn panic(_panic: &PanicInfo<'_>) -> ! {
    loop {}
}

// Here we set up things, and jump to entry()
//
// N.b. this setup isn't good enough to run appropriate software. General
// purpose registers are not zeroed among other things.
global_asm! {
    ".section .init, \"ax\"",
    ".global reset",
    "reset:",
        "la t1, _stack_start",
        "andi sp, t1, -4", // align stack to 4-bytes (RV32E-specific)
        "add s0, sp, zero",
        // pre_init and stuff
        "j entry"
}

/// The reset vector, a pointer into the reset handler
#[link_section = ".vectors"]
#[no_mangle]
// HACK: just a placeholder
fn _jump_table() {
    unsafe {
        asm!("j reset");
        asm!("j reset");
        asm!("j reset");
        asm!("j reset");
    }
}
