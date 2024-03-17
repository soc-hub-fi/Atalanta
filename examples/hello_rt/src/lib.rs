#![no_std]
#![no_main]

pub use mmap;
pub use ufmt;

pub mod clic;
pub mod debug;
pub mod irq;
pub mod led;
pub mod sprint;
pub mod tb;
pub mod uart;

use core::{
    arch::{asm, global_asm},
    panic::PanicInfo,
};
use riscv::register::mtvec;

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

/// Blinks the leds fast in a confused fashion (3 -> 1 -> 2 -> 0 -> 3)
#[panic_handler]
fn panic_handler(_info: &PanicInfo) -> ! {
    match () {
        #[cfg(feature = "rtl-tb")]
        () => tb::rtl_testbench_signal_fail(),
        #[cfg(feature = "fpga")]
        () => tb::blink_panic(),
    }
}

#[export_name = "_setup_interrupts"]
fn setup_interrupt_vector() {
    // Set the trap vector
    unsafe {
        extern "C" {
            fn _trap_vector();
        }

        // Set all the trap vectors for good measure
        let bits = _trap_vector as usize;
        mtvec::write(bits, mtvec::TrapMode::Clic);
        // 0x307 = mtvt
        asm!("csrw 0x307, {0}", in(reg) bits | 0x3);

        // 0x347 = mintthresh
        asm!("csrw 0x347, 0x00");
    }
}

// The vector table
//
// Do the ESP trick and route all interrupts to the direct dispatcher.
//
// N.b. vectors length must be exactly 0x80
global_asm!(
    "
.section .vectors, \"ax\"
    .global _trap_vector
    // Trap vector base address must always be aligned on a 4-byte boundary
    .align 4
_trap_vector:
    j _start_trap
    .rept 31
    .word _start_trap // 1..31
    .endr
"
);

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
