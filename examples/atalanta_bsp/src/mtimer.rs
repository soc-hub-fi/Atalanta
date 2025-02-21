use crate::{
    mask_u32,
    mmap::{
        MTIMECMP_HIGH_ADDR_OFS, MTIMECMP_LOW_ADDR_OFS, MTIMER_BASE, MTIME_CTRL_ADDR_OFS,
        MTIME_HIGH_ADDR_OFS, MTIME_LOW_ADDR_OFS,
    },
    read_u32, unmask_u32, write_u32, CPU_FREQ,
};

/// Machine Timer
///
/// This timer is associated with [crate::Interrupt::MachineTimer]
pub struct MTimer {}

impl MTimer {
    /// Returns the global mtimer instance
    #[inline]
    pub fn instance() -> Self {
        Self {}
    }

    /// Starts the count
    ///
    /// `prescaler` must be less than or equal to 7
    #[inline]
    pub fn enable_with_prescaler(&mut self, prescaler: u32) {
        debug_assert!(prescaler <= 0b111);

        // Enable timer (bit 0) & set prescaler (bits 10:8)
        write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, (prescaler << 8) | 0b1);
    }

    /// Starts the count
    #[inline]
    pub fn enable(&mut self) {
        mask_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0b1);
    }

    /// Stops the count & disables the interrupt line on the core
    ///
    /// Note that disabling the mtimer can be unexpected behavior.
    #[inline]
    pub fn disable(&mut self) {
        unmask_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0b1);
    }

    /// N.b., you may sometimes get a disjoint value if the function gets
    /// interrupted in the middle of the read transaction
    #[inline]
    pub fn counter(&self) -> u64 {
        let hi = read_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS);
        let lo = read_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS);
        let mtime = ((hi as u64) << 32) | lo as u64;
        mtime
    }

    #[inline]
    pub unsafe fn set_counter(&mut self, cnt: u64) {
        write_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS, cnt as u32);
        write_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS, (cnt >> 32) as u32);
    }

    /// Resets mtime to zero, disables the count & sets compare to u32::MAX,
    /// making sure no more interrupts will fire (n.b., an interrupt might
    /// already be pending and this will not lower it).
    #[inline]
    pub fn reset(&mut self) {
        write_u32(MTIMER_BASE + MTIME_CTRL_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIME_HIGH_ADDR_OFS, 0);
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, u32::MAX);
        write_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS, u32::MAX);
    }

    /// Gets the timer compare value
    ///
    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    #[inline]
    pub unsafe fn cmp(&mut self) -> u64 {
        ((read_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS) as u64) << 32)
            | read_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS) as u64
    }

    /// Sets the timer compare value
    ///
    /// Interrupt signal is raised (and held) on `timer >= timer_cmp`.
    #[inline]
    pub fn set_cmp(&mut self, cmp: u64) {
        // Setting low value to max first prevents the register from being temporarily
        // reduced by a transaction that is intended for increasing the total
        // value.
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, u32::MAX);
        write_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS, (cmp >> 32) as u32);
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, cmp as u32);
    }

    #[inline]
    pub fn into_lo(self) -> MTimerLo {
        MTimerLo(self)
    }

    #[inline]
    pub fn into_oneshot(self) -> OneShot {
        OneShot(self)
    }
}

/// Machine Timer, lower bits only
///
/// This timer is associated with [crate::Interrupt::MachineTimer]
pub struct MTimerLo(MTimer);

impl MTimerLo {
    /// Starts the count
    ///
    /// `prescaler` must be less than or equal to 7
    #[inline]
    pub fn enable_with_prescaler(&mut self, prescaler: u32) {
        self.0.enable_with_prescaler(prescaler)
    }

    /// Starts the count
    #[inline]
    pub fn enable(&mut self) {
        self.0.enable()
    }

    /// Stops the count & disables the interrupt line on the core
    ///
    /// Note that disabling the mtimer can be unexpected behavior.
    #[inline]
    pub fn disable(&mut self) {
        self.0.disable()
    }

    #[inline]
    pub fn counter(&self) -> u32 {
        read_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS)
    }

    #[inline]
    pub unsafe fn set_counter(&mut self, cnt: u32) {
        write_u32(MTIMER_BASE + MTIME_LOW_ADDR_OFS, cnt);
    }

    /// Resets mtime to zero, disables the count & sets compare to u32::MAX,
    /// making sure no more interrupts will fire (n.b., an interrupt might
    /// already be pending and this will not lower it).
    #[inline]
    pub fn reset(&mut self) {
        self.0.reset()
    }

    /// Gets the timer compare value
    ///
    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    #[inline]
    pub unsafe fn cmp(&mut self) -> u32 {
        read_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS)
    }

    /// Sets the timer compare value
    ///
    /// Interrupt signal is raised (and held) on `timer >= timer_cmp`.
    #[inline]
    pub fn set_cmp(&mut self, cmp: u32) {
        // Setting low value to max first prevents the register from being temporarily
        // reduced by a transaction that is intended for increasing the total
        // value.
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, u32::MAX);
        write_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS, 0x0);
        write_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS, cmp as u32);
    }
}

const PERIPH_CLK_DIV: u32 = 1;
const DENOM: u32 = CPU_FREQ / PERIPH_CLK_DIV;
pub type Duration = fugit::Duration<u64, 1, DENOM>;

pub struct OneShot(MTimer);

impl OneShot {
    /// Schedules the `MachineTimer` interrupt to trigger after `duration`
    #[inline]
    pub fn start(&mut self, duration: Duration) {
        let cnt = self.0.counter();
        self.0.set_cmp(cnt + duration.ticks());
        self.0.enable();
    }

    /// Unschedules the `MachineTimer' interrupt by setting mtimecmp to
    /// `u64::MAX`
    ///
    /// Note that an interrupt may be pending already when this is called, which
    /// won't be unscheduled. Call `Clic::ip(int).unpend` instead.
    #[inline]
    pub fn cancel(&mut self) {
        self.0.set_cmp(u64::MAX);
    }

    /// Gets the timer compare value
    ///
    /// Safety: needs to be called in an interrupt critical-section, otherwise
    /// you risk getting interrupted in between reading the hi & low address and
    /// getting a disjoint value
    #[inline]
    pub unsafe fn cmp(&mut self) -> u64 {
        ((read_u32(MTIMER_BASE + MTIMECMP_HIGH_ADDR_OFS) as u64) << 32)
            | read_u32(MTIMER_BASE + MTIMECMP_LOW_ADDR_OFS) as u64
    }
}

impl From<OneShot> for MTimer {
    fn from(value: OneShot) -> Self {
        value.0
    }
}
