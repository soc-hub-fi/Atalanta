use crate::{
    mmap::timer_queue::{RegisterBlock, TIMER_QUEUE_BASE},
    read_u32p, write_u32p,
};

/// Driver for AnTiQ
pub struct TimerQueue(*mut RegisterBlock);

impl TimerQueue {
    #[inline]
    pub fn init() -> Self {
        let tim_q = Self(TIMER_QUEUE_BASE as *mut _);

        // Clear the timer queue
        while !tim_q.is_empty() {
            let top = tim_q.top_idx();
            tim_q.drop(top);
        }

        tim_q
    }

    /// # Safety
    ///
    /// Returns a potentially uninitialized instance of timer queue
    #[inline]
    pub unsafe fn instance() -> Self {
        Self(TIMER_QUEUE_BASE as *mut _)
    }

    #[inline]
    pub fn is_empty(&self) -> bool {
        let p = self.0;
        let status = read_u32p(unsafe { &mut (*p).status as *mut u32 });
        let is_empty = (status & (0b1 << 8)) != 0;
        is_empty
    }

    #[inline]
    pub fn drop(&self, handle: u8) {
        let p = self.0;

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Drop trigger
            0b1 << 8
            |
            // Drop handle
            (handle as u32) << 24,
        );
    }

    #[inline]
    pub fn top_idx(&self) -> u8 {
        let p = self.0;

        let top = read_u32p(unsafe { &mut (*p).top_idx as *mut u32 });

        top as u8
    }

    #[inline]
    pub fn btm_idx(&self) -> u8 {
        let p = self.0;

        let btm = read_u32p(unsafe { &mut (*p).btm_idx as *mut u32 });

        btm as u8
    }

    #[inline]
    pub fn last_idx(&self) -> u8 {
        let p = self.0;

        let last = read_u32p(unsafe { &mut (*p).last_idx as *mut u32 });

        last as u8
    }

    #[inline]
    pub fn push_rel(&self, ofs: u64, payload: u8) -> u8 {
        let p = self.0;

        write_u32p(unsafe { &mut (*p).p_rel_lo as *mut u32 }, ofs as u32);
        write_u32p(
            unsafe { &mut (*p).p_rel_hi as *mut u32 },
            (ofs >> 32) as u32,
        );

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Push trigger
            0b1
            |
            // Push payload
            (payload as u32) << 16,
        );

        read_u32p(unsafe { &mut (*p).last_idx as *mut u32 }) as u8
    }

    #[inline]
    pub fn push_abs(&self, timestamp: u64, payload: u8) -> u8 {
        let p = self.0;

        write_u32p(unsafe { &mut (*p).p_abs_lo as *mut u32 }, timestamp as u32);
        write_u32p(
            unsafe { &mut (*p).p_abs_hi as *mut u32 },
            (timestamp >> 32) as u32,
        );

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Push trigger
            0b1
            |
            // Push payload
            (payload as u32) << 16,
        );

        read_u32p(unsafe { &mut (*p).last_idx as *mut u32 }) as u8
    }
}
