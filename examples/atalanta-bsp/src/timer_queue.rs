use crate::{
    mmap::timer_queue::{RegisterBlock, TIMER_QUEUE_BASE},
    read_u32p, write_u32p,
};

#[derive(Clone)]
#[cfg_attr(feature = "ufmt", derive(ufmt::derive::uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
pub struct Entry {
    /// Timestamp (absolute value or offset)
    pub ts: u64,
    pub irq_id: u8,
}

impl Entry {
    /// Construct a new timer queue entry with a timestamp and an IRQ id
    pub fn new(ts: u64, irq_id: u8) -> Self {
        Self { ts, irq_id }
    }
}

/// Driver for AnTiQ
pub struct TimerQueue(*mut RegisterBlock);

impl TimerQueue {
    #[inline(always)]
    pub fn init() -> Self {
        let mut tim_q = Self(TIMER_QUEUE_BASE as *mut _);

        tim_q.reset();

        tim_q
    }

    #[inline(always)]
    pub fn reset(&mut self) {
        // Clear the timer queue
        while !self.is_empty() {
            let top = self.top_idx();
            self.drop(top);
        }
    }

    /// # Safety
    ///
    /// Returns a potentially uninitialized instance of timer queue
    #[inline(always)]
    pub unsafe fn instance() -> Self {
        Self(TIMER_QUEUE_BASE as *mut _)
    }

    #[inline(always)]
    pub fn is_empty(&self) -> bool {
        let p = self.0;
        let status = read_u32p(unsafe { &mut (*p).status as *mut u32 });
        let is_empty = (status & (0b1 << 8)) != 0;
        is_empty
    }

    #[inline(always)]
    pub fn is_full(&self) -> bool {
        let p = self.0;
        let status = read_u32p(unsafe { &mut (*p).status as *mut u32 });
        let is_full = (status & 0b1) != 0;
        is_full
    }

    /// Returns hardware queue maximum depth
    ///
    /// This is also the non-inclusive upper bound for handle/index value.
    #[inline(always)]
    pub fn capacity(&self) -> u32 {
        let p = self.0;
        let status = read_u32p(unsafe { &mut (*p).status as *mut u32 });
        let depth_minus_one = ((status & (0xff << 24)) >> 24) as u8;
        depth_minus_one as u32 + 1
    }

    /// Returns absolute timestamp and stored interrupt id of dropped entry
    #[inline(always)]
    pub fn drop(&mut self, handle: u8) -> Entry {
        let p = self.0;

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Drop trigger
            0b1 << 8
            |
            // Drop handle
            (handle as u32) << 24,
        );

        let payload = read_u32p(unsafe { &mut (*p).d_payload as *mut u32 });
        let dispatch_lo = read_u32p(unsafe { &mut (*p).d_dispatch_lo as *mut u32 });
        let dispatch_hi = read_u32p(unsafe { &mut (*p).d_dispatch_hi as *mut u32 });

        Entry {
            ts: (dispatch_lo as u64) | (dispatch_hi as u64) << 32,
            irq_id: payload as u8,
        }
    }

    /// Handle for smallest ("next to trigger") value
    #[inline(always)]
    pub fn top_idx(&self) -> u8 {
        let p = self.0;

        let top = read_u32p(unsafe { &mut (*p).top_idx as *mut u32 });

        top as u8
    }

    /// Handle for biggest ("last to trigger") value
    #[inline(always)]
    pub fn btm_idx(&self) -> u8 {
        let p = self.0;

        let btm = read_u32p(unsafe { &mut (*p).btm_idx as *mut u32 });

        btm as u8
    }

    /// Handle for last pushed value
    #[inline(always)]
    pub fn last_idx(&self) -> u8 {
        let p = self.0;

        let last = read_u32p(unsafe { &mut (*p).last_idx as *mut u32 });

        last as u8
    }

    /// * `irq_id` - Timer queue interrupt id ("TqId"), *not* platform level
    ///   interrupt id.
    /// * `ts` - Target dispatch time, relative to mtimer
    #[inline(always)]
    pub fn push_rel(&mut self, e: Entry) -> u8 {
        // Current impl of timer queue only supports offsets representable with 24 bits
        // or less
        debug_assert!(e.ts < (0b1 << 24));

        let p = self.0;

        write_u32p(unsafe { &mut (*p).p_rel_lo as *mut u32 }, e.ts as u32);
        write_u32p(
            unsafe { &mut (*p).p_rel_hi as *mut u32 },
            (e.ts >> 32) as u32,
        );

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Push trigger
            0b1
            |
            // Push irq
            (e.irq_id as u32) << 16,
        );

        read_u32p(unsafe { &mut (*p).last_idx as *mut u32 }) as u8
    }

    /// * `irq` - Timer queue interrupt id ("TqId"), *not* platform level
    ///   interrupt id.
    /// * `ts` - Target absolute dispatch time, relative to mtimer
    #[inline(always)]
    pub fn push_abs(&mut self, e: Entry) -> u8 {
        // Current impl of timer queue only supports offsets representable with 24 bits
        // or less
        debug_assert!(e.ts < (0b1 << 24));

        let p = self.0;

        write_u32p(unsafe { &mut (*p).p_abs_lo as *mut u32 }, e.ts as u32);
        write_u32p(
            unsafe { &mut (*p).p_abs_hi as *mut u32 },
            (e.ts >> 32) as u32,
        );

        write_u32p(
            unsafe { &mut (*p).pd_ctrl as *mut u32 },
            // Push trigger
            0b1
            |
            // Push irq
            (e.irq_id as u32) << 16,
        );

        read_u32p(unsafe { &mut (*p).last_idx as *mut u32 }) as u8
    }
}
