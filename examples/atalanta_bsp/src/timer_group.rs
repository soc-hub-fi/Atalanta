use crate::{mask_u32p, mmap::apb_timer::*, read_u32p, unmask_u32p, write_u32p, CPU_FREQ};

/// Relocatable driver for PULP APB Timer IP
pub struct Timer(*mut RegisterBlock);

impl Timer {
    /// Initializes a timer with all values initialized to zero
    #[inline]
    pub fn init<const BASE_ADDR: usize>() -> Self {
        let timer = Self(BASE_ADDR as *mut _);
        // Disable timer & zero prescaler
        write_u32p(unsafe { &mut (*timer.0).ctrl as *mut u32 }, 0);
        // Set compare to max. N.b., setting compare also zeros the counter.
        write_u32p(unsafe { &mut (*timer.0).cmp as *mut u32 }, u32::MAX);
        timer
    }

    /// # Safety
    ///
    /// Returns a potentially uninitialized instance of APB Timer
    #[inline]
    pub unsafe fn instance<const BASE_ADDR: usize>() -> Self {
        Self(BASE_ADDR as *mut _)
    }

    /// Starts the count
    #[inline]
    pub fn enable(&mut self) {
        mask_u32p(
            unsafe { &mut (*self.0).ctrl as *mut u32 },
            TIMER_CTRL_ENABLE_BIT,
        );
    }

    /// Starts the count
    ///
    /// `prescaler` must be less than 7
    #[inline]
    pub fn enable_with_prescaler(&mut self, prescaler: u32) {
        debug_assert!(prescaler <= 0b111);

        write_u32p(
            unsafe { &mut (*self.0).ctrl as *mut u32 },
            (prescaler << TIMER_CTRL_PRESCALER_BIT_IDX) | TIMER_CTRL_ENABLE_BIT,
        );
    }

    /// Stops the count
    #[inline]
    pub fn disable(&mut self) {
        unmask_u32p(
            unsafe { &mut (*self.0).ctrl as *mut u32 },
            TIMER_CTRL_ENABLE_BIT,
        );
    }

    /// Get current timer counter value
    #[inline]
    pub fn counter(&self) -> u32 {
        read_u32p(unsafe { &mut (*self.0).cnt as *mut u32 })
    }

    /// Set current timer counter value
    #[inline]
    pub fn set_counter(&mut self, cnt: u32) {
        #[cfg(debug_assertions)]
        {
            // Counter must not be set to a value higher than compare
            let cmp = read_u32p(unsafe { &mut (*self.0).cmp as *mut u32 });
            debug_assert!(cnt <= cmp);
        }
        write_u32p(unsafe { &mut (*self.0).cnt as *mut u32 }, cnt)
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
        write_u32p(unsafe { &mut (*self.0).cmp as *mut u32 }, cmp);
    }

    #[inline]
    pub fn into_periodic(self) -> Periodic {
        Periodic(self)
    }
}

const PERIPH_CLK_DIV: u32 = 1;
const DENOM: u32 = CPU_FREQ / PERIPH_CLK_DIV;
pub type Duration = fugit::Duration<u32, 1, DENOM>;

pub struct Periodic(Timer);

impl Periodic {
    /// Schedules an interrupt to be fired every `duration`. Call [Self::start]
    /// to start the timer.
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
