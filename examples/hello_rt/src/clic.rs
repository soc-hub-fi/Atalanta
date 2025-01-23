//! Ad-hoc CLIC impl based on the respective C code
//!
//! This is the old API.
use bsp::mmap::*;
use bsp::*;

/* CLIC interrupt id control */
pub const CLIC_NBITS: usize = 8;
pub const CLIC_CLICINTCTL_CTL_MASK: usize = 0xff;
pub const CLIC_CLICINTCTL_CTL_OFFSET: usize = 24 + (8 - CLIC_NBITS);

#[repr(u32)]
pub enum ClicTrig {
    Level = 0,
    Edge = 1,
}

#[inline]
pub fn set_mnlbits(mnlbits: u32) {
    write_u32(CLIC_BASE_ADDR, mnlbits);
}

#[inline]
pub fn set_trig(id: u32, trig: ClicTrig) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        trig as u32,
        CLIC_CLICINTATTR_TRIG_MASK as u32,
        CLIC_CLICINTATTR_TRIG_OFFSET,
    );
}

#[inline]
pub fn enable_int(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x1,
        CLIC_CLICINTIE_IE_MASK as u32,
        CLIC_CLICINTIE_IE_BIT,
    );
}

#[inline]
pub fn disable_int(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x0,
        CLIC_CLICINTIE_IE_MASK as u32,
        CLIC_CLICINTIE_IE_BIT,
    );
}

#[inline]
pub fn pend_int(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x1,
        CLIC_CLICINTIE_IP_MASK as u32,
        CLIC_CLICINTIE_IP_BIT,
    );
}

#[inline]
pub fn set_level(id: u32, level: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        level,
        CLIC_CLICINTCTL_CTL_MASK as u32,
        CLIC_CLICINTCTL_CTL_OFFSET,
    );
}

// Resets interrupt #id pending bit
pub fn ack_int(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x0,
        CLIC_CLICINTIE_IP_MASK as u32,
        CLIC_CLICINTIE_IP_BIT,
    );
}

/// Enable Vectored interrupt handling for interrupt #id
/// CPU thus jumps to the common interrupt handler at xtvec
#[inline]
pub fn enable_vectoring(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x1,
        CLIC_CLICINTATTR_SHV_MASK as u32,
        CLIC_CLICINTATTR_SHV_BIT,
    );
}

/*
    Disable Vectored interrupt handling for interrupt #id
*/
#[inline]
pub fn disable_vectoring(id: u32) {
    modify_u32(
        CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id),
        0x0,
        CLIC_CLICINTATTR_SHV_MASK as u32,
        CLIC_CLICINTATTR_SHV_BIT,
    );
}
