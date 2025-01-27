use crate::{
    mask_u32,
    mmap::{
        MTIMECMP_HIGH_ADDR_OFS, MTIMECMP_LOW_ADDR_OFS, MTIMER_BASE, MTIME_CTRL_ADDR_OFS,
        MTIME_HIGH_ADDR_OFS, MTIME_LOW_ADDR_OFS,
    },
    read_u32, write_u32,
};

pub struct MTimer {}

impl MTimer {
    /// Initializes a timer with all values initialized to zero
    #[inline]
    pub fn init() -> Self {
        let mut timer = Self {};
        // Reset sets all values to zero
        timer.reset();
        timer
    }

    /// # Safety
    ///
    /// Returns a potentially uninitialized instance of APB Timer
    #[inline]
    pub unsafe fn instance() -> Self {
        Self {}
    }

    /// Starts the count
    ///
    /// `prescaler` must be less than 8191
    #[inline]
    pub fn enable_with_prescaler(&mut self, prescaler: u32) {
        debug_assert!(prescaler <= 0b1_1111_1111_1111);

        // Enable timer (bit 0) & set prescaler (bits 20:8)
        write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, (prescaler << 8) | 0b1);
    }

    /// Starts the count
    #[inline]
    pub fn enable(&mut self) -> Self {
        mask_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0b1);
        Self {}
    }

    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    pub unsafe fn counter(&mut self) -> u64 {
        let lo = read_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS);
        let hi = read_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS);
        let mtime = ((hi as u64) << 32) + lo as u64;
        mtime
    }

    /// Initializes all values to zero
    #[inline]
    pub fn reset(&mut self) {
        write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS, 0);
    }

    /// Sets the timer compare value
    ///
    /// Interrupt signal is raised on `timer >= timer_cmp`.
    ///
    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    #[inline]
    pub unsafe fn set_cmp(&mut self, cmp: u64) {
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, cmp as u32);
        write_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS, (cmp >> 32) as u32);
    }
}
