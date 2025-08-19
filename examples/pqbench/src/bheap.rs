use bsp::{clic::Clic, Interrupt};
use heapless::binary_heap::Min;

use crate::{Dispatch, Entry, PQueue};

// TODO: free_handles should possibly be a hashset instead of dequeue

pub struct BHeap<const Q_LEN: usize> {
    pub queued: heapless::BinaryHeap<Entry, Min, Q_LEN>,
    free_handles: heapless::Deque<u8, Q_LEN>,
    /// Monotonic timer for classic dispatch using monotonics
    pub mtimer: bsp::mtimer::MTimer,
    pub active_handle: Option<u8>,
}

impl<const Q_LEN: usize> BHeap<Q_LEN> {
    pub fn new(mut mtimer: bsp::mtimer::MTimer) -> Self {
        let mut free_handles = heapless::Deque::new();
        for h in 0..Q_LEN {
            unsafe { free_handles.push_back(h as u8).unwrap_unchecked() }
        }

        // Make sure mtimer is enabled, as it is required for dispatch
        mtimer.enable();

        BHeap {
            queued: heapless::BinaryHeap::new(),
            free_handles,
            mtimer,
            active_handle: None,
        }
    }
}

// Software binary heap + handle lookup
impl<const Q_LEN: usize> PQueue for BHeap<Q_LEN> {
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
                    unsafe {
                        self.queued
                            .push(Entry::with_handle(entry, h))
                            .unwrap_unchecked()
                    }
                }
            }
            // Proposed timestamp is less urgent than what is currently programmed
            else {
                // Enqueue the proposed entry with a resolved absolute timestamp
                let entry = Self::Entry { ts, ..entry };

                // Safety: we never insert more than what the queue can take in our testbench
                // !!!: Failure is UB
                unsafe {
                    self.queued
                        .push(Entry::with_handle(entry, h))
                        .unwrap_unchecked()
                }
            }

            h
        })
    }

    /// Parameter uses absolute timestamp
    #[inline(always)]
    fn enqueue_abs(&mut self, entry: Self::Entry) -> u8 {
        let ts = entry.ts;
        bsp::riscv::interrupt::free(|| {
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
                    unsafe {
                        self.queued
                            .push(Entry::with_handle(entry, h))
                            .unwrap_unchecked()
                    }
                }
            }
            // Proposed timestamp is less urgent than what is currently programmed
            else {
                // Enqueue the proposed entry with a resolved absolute timestamp
                let entry = Self::Entry { ts, ..entry };

                // Safety: we never insert more than what the queue can take in our testbench
                // !!!: Failure is UB
                unsafe {
                    self.queued
                        .push(Entry::with_handle(entry, h))
                        .unwrap_unchecked()
                }
            }

            h
        })
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| {
            // If the requested drop handle is currently timered
            if self.active_handle.is_some_and(|a| a == handle) {
                // Return the handle into the pool of free handles
                // Safety: we hope that there is enough capacity for all handles in our test
                // case.
                // !!!: Failure is UB
                unsafe { self.free_handles.push_back(handle).unwrap_unchecked() };

                // Enqueue a new value from the queue if available and make it the active handle
                self.active_handle = self.queued.pop().map(|e| {
                    self.mtimer.set_cmp(e.ts);
                    e.1
                });
                return;
            }

            // Arbitrary drop: reallocate the entire data structure

            let retain = self
                .queued
                .into_iter()
                .filter(|entry| entry.1 != handle)
                .cloned();
            let mut nq = heapless::BinaryHeap::new();
            for val in retain {
                unsafe { nq.push(val).unwrap_unchecked() };
            }
            self.queued = nq;
            // Safety: we hope that there is enough capacity for all handles in our test
            // case.
            // !!!: Failure is UB
            unsafe { self.free_handles.push_back(handle).unwrap_unchecked() };
        })
    }
}

impl<const Q_LEN: usize> Dispatch for BHeap<Q_LEN> {
    #[inline(always)]
    fn dispatch(&mut self) {
        // Safety: active handle matches currently with the event being dispatched
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
            .pop()
            .map(|e| {
                self.mtimer.set_cmp(e.ts);
                e.1
            })
            .or_else(|| {
                // No events in queue => set mtimer to never fire
                self.mtimer.set_cmp(u64::MAX);
                None
            });

        // Pend the hardware dispatcher
        unsafe { Clic::ip(Interrupt::TqId0).pend() };
    }
}
