use crate::{
    mmap::{MTIMER_BASE, MTIME_CTRL_ADDR_OFS, MTIME_HIGH_ADDR_OFS, MTIME_LOW_ADDR_OFS},
    read_u32, write_u32,
};

pub struct MTimer {}

impl MTimer {
    pub fn en(prescaler: u32) -> Self {
        // Enable timer (bit 0) & set prescaler (bits 20:8)
        write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, prescaler << 8 | 0b1);
        Self {}
    }

    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    pub unsafe fn read(&mut self) -> u64 {
        let lo = read_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS);
        let hi = read_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS);
        let mtime = ((hi as u64) << 32) + lo as u64;
        mtime
    }
}
