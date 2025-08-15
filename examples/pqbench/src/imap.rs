use bsp::{clic::Clic, Interrupt};

use crate::{Dispatch, PQueue};

// TODO: free_handles should possibly be a hashset instead of dequeue

pub struct IMap<const Q_LEN: usize> {
    queued: heapless::FnvIndexMap<u8, bsp::timer_queue::Entry, Q_LEN>,
    free_handles: heapless::Deque<u8, Q_LEN>,
    /// Monotonic timer for classic dispatch using monotonics
    mtimer: bsp::mtimer::MTimer,
    pub active_handle: Option<u8>,
}

impl<const Q_LEN: usize> IMap<Q_LEN> {
    pub fn new(mut mtimer: bsp::mtimer::MTimer) -> Self {
        let mut free_handles = heapless::Deque::new();
        for h in 0..Q_LEN {
            free_handles.push_back(h as u8).unwrap()
        }

        // Make sure mtimer is enabled, as it is required for dispatch
        mtimer.enable();

        IMap {
            queued: heapless::IndexMap::new(),
            free_handles,
            mtimer,
            active_handle: None,
        }
    }
}

impl<const Q_LEN: usize> PQueue for IMap<Q_LEN> {
    type Entry = bsp::timer_queue::Entry;

    /// Parameter uses relative timestamp (stored with resolved absolute)
    #[inline(always)]
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| {
            // Resolve absolute timestamp
            let ts = self.mtimer.counter() + entry.ts;

            // Generate a handle for the value to be enqueued
            // Safety: we hope that there is enough free handles for our test case.
            // !!!: Failure is UB
            let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };

            // Check if proposed timestamp is more urgent than what is currently programmed
            let prog = unsafe { self.mtimer.cmp() };
            if ts < prog {
                // Program mtimer to fire on the proposed timestamp and enqueue the previous
                // value
                self.mtimer.set_cmp(ts);
                self.active_handle = Some(h);

                if prog != u64::MAX {
                    // Safety: we never insert more than what the queue can take in our testbench
                    // !!!: Failure is UB
                    let entry = Self::Entry { ts: prog, ..entry };
                    unsafe { self.queued.insert(h, entry).unwrap_unchecked() };
                }
            }
            // Proposed timestamp is less urgent than what is currently programmed
            else {
                // Enqueue the proposed entry with a resolved absolute timestamp
                let entry = Self::Entry { ts, ..entry };

                // Safety: we never insert more than what the queue can take in our testbench
                // !!!: Failure is UB
                unsafe { self.queued.insert(h, entry).unwrap_unchecked() };
            }

            h
        })
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| {
            self.queued.remove(&handle);

            // Safety: we hope that there is enough capacity for all handles in our test
            // case.
            // !!!: Failure is UB
            unsafe { self.free_handles.push_back(handle).unwrap_unchecked() };
        })
    }
}

impl<const Q_LEN: usize> Dispatch for IMap<Q_LEN> {
    #[inline(always)]
    fn dispatch(&mut self) {
        // Safety: since we are dispatching right now, we are confident that there is
        // indeed an active handle.
        let handle = unsafe { self.active_handle.unwrap_unchecked() };

        // Return the handle into the pool of free handles
        // Safety: we hope that there is enough capacity for all handles in our test
        // case.
        // !!!: Failure is UB
        unsafe { self.free_handles.push_back(handle).unwrap_unchecked() };

        // Enqueue a new value from the queue if available, and make it the active
        // handle

        self.active_handle = self
            .queued
            .iter()
            .min_by(|(_, a), (_, b)| a.ts.cmp(&b.ts))
            .map(|e| {
                self.mtimer.set_cmp(e.1.ts);
                *e.0
            })
            .or_else(|| {
                // No events in queue => set mtimer to never fire
                self.mtimer.set_cmp(u64::MAX);
                None
            });

        unsafe { Clic::ip(Interrupt::TqId0).pend() };
    }
}
