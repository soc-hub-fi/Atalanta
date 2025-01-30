use crate::{mask_u32, mmap::apb_timer::*, read_u32, unmask_u32, write_u32, CPU_FREQ};

/// Relocatable driver for PULP APB Timer IP
pub struct TimerUnit<const BASE_ADDR: usize>;

impl<const BASE_ADDR: usize> TimerUnit<BASE_ADDR> {
    /// Initializes a timer with all values initialized to zero
    #[inline]
    pub fn init() -> Self {
        let timer = Self {};
        // Disable timer & zero prescaler
        write_u32(BASE_ADDR + TIMER_CTRL_OFS, 0);
        // Set compare to max. N.b., setting compare also zeros the counter.
        write_u32(BASE_ADDR + TIMER_CMP_OFS, u32::MAX);
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
    #[inline]
    pub fn enable(&mut self) {
        mask_u32(BASE_ADDR + TIMER_CTRL_OFS, TIMER_CTRL_ENABLE_BIT);
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

    /// Stops the count
    #[inline]
    pub fn disable(&mut self) {
        unmask_u32(BASE_ADDR + TIMER_CTRL_OFS, TIMER_CTRL_ENABLE_BIT);
    }

    /// Get current timer counter value
    #[inline]
    pub fn counter(&mut self) -> u32 {
        read_u32(BASE_ADDR + TIMER_COUNTER_OFS)
    }

    /// Set current timer counter value
    #[inline]
    pub fn set_counter(&mut self, cnt: u32) {
        write_u32(BASE_ADDR + TIMER_COUNTER_OFS, cnt)
    }

    /// Sets the timer compare value
    ///
    /// N.b., setting compare also zeros the counter.
    ///
    /// On `timer >= timer_cmp`:
    ///
    /// * interrupt signal for corresponding Timer is raised, and
    /// * `counter` value is reset to zero.
    #[inline]
    pub fn set_cmp(&mut self, cmp: u32) {
        write_u32(BASE_ADDR + TIMER_CMP_OFS, cmp);
    }

    #[inline]
    pub fn into_periodic(self) -> Periodic<BASE_ADDR> {
        Periodic(self)
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

const PERIPH_CLK_DIV: u32 = 2;
const DENOM: u32 = CPU_FREQ / PERIPH_CLK_DIV;
pub type Duration = fugit::Duration<u32, 1, DENOM>;

pub struct Periodic<const BASE_ADDR: usize>(TimerUnit<BASE_ADDR>);

impl<const BASE_ADDR: usize> Periodic<BASE_ADDR> {
    /// Schedules an interrupt to be fired every `duration`
    ///
    /// Also resets the internal counter.
    #[inline]
    pub fn set_period(&mut self, duration: Duration) {
        // Setting CMP also sets COUNTER
        self.0.set_cmp(duration.ticks());
    }

    /// Schedules an interrupt to be fired every `duration`
    ///
    /// Also sets the counter to a specific value, allowing to trigger the first
    /// interrupt ahead of schedule.
    #[inline]
    pub fn set_period_offset(&mut self, period: Duration, offset: Duration) {
        // Setting CMP also sets COUNTER, so we override that afterwards
        self.0.set_cmp(period.ticks());
        self.0.set_counter(offset.ticks());
    }

    /// Starts the timer
    #[inline]
    pub fn start(&mut self) {
        self.0.enable();
    }

    /// Disables the timer and sets compare to max
    #[inline]
    pub fn cancel(&mut self) {
        self.0.disable();
        self.0.set_cmp(u32::MAX);
    }
}
