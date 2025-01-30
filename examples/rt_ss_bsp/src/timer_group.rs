use crate::{mask_u32, mmap::apb_timer::*, read_u32, unmask_u32, write_u32};

/// Relocatable driver for PULP APB Timer IP
pub struct TimerUnit<const BASE_ADDR: usize>;

impl<const BASE_ADDR: usize> TimerUnit<BASE_ADDR> {
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
    /// `prescaler` must be less than 7
    #[inline]
    pub fn enable_with_prescaler(&mut self, prescaler: u32) {
        debug_assert!(prescaler <= 0b111);

        write_u32(
            BASE_ADDR + TIMER_CTRL_OFS,
            (prescaler << TIMER_CTRL_PRESCALER_BIT_IDX) | TIMER_CTRL_ENABLE_BIT,
        );
    }

    /// Starts the count
    #[inline]
    pub fn enable(&mut self) {
        mask_u32(BASE_ADDR + TIMER_CTRL_OFS, TIMER_CTRL_ENABLE_BIT);
    }

    /// Stops the count
    #[inline]
    pub fn disable(&mut self) {
        unmask_u32(BASE_ADDR + TIMER_CTRL_OFS, TIMER_CTRL_ENABLE_BIT);
    }

    /// Get current timer value
    #[inline]
    pub fn counter(&mut self) -> u32 {
        read_u32(BASE_ADDR + TIMER_COUNTER_OFS)
    }

    /// Set current counter value
    #[inline]
    pub fn set_counter(&mut self, cnt: u32) {
        write_u32(BASE_ADDR + TIMER_COUNTER_OFS, cnt)
    }

    /// Initializes all values to zero
    #[inline]
    pub fn reset(&mut self) {
        write_u32(BASE_ADDR + TIMER_CTRL_OFS, 0);
        write_u32(BASE_ADDR + TIMER_COUNTER_OFS, 0);
        write_u32(BASE_ADDR + TIMER_CMP_OFS, u32::MAX);
    }

    /// Sets the timer compare value
    ///
    /// On `timer >= timer_cmp`:
    ///
    /// * interrupt signal for corresponding Timer is raised, and
    /// * `counter` value is reset to zero.
    #[inline]
    pub fn set_cmp(&mut self, cmp: u32) {
        write_u32(BASE_ADDR + TIMER_CMP_OFS, cmp);
    }
}

/// Type alias that should be used to interface timer 0.
pub type Timer0 = TimerUnit<TIMER0_ADDR>;
/// Type alias that should be used to interface timer 1.
pub type Timer1 = TimerUnit<TIMER1_ADDR>;
/// Type alias that should be used to interface timer 2.
pub type Timer2 = TimerUnit<TIMER2_ADDR>;
/// Type alias that should be used to interface timer 3.
pub type Timer3 = TimerUnit<TIMER3_ADDR>;
