#![no_std]
#![no_main]

#[cfg(not(any(feature = "use-hwq", feature = "use-imap", feature = "use-bheap")))]
compile_error!("must select `use-hwq`, `use-imap`, or `use-bheap`");

use core::ops;

use bsp::{
    clic::{Clic, Polarity, Trig},
    timer_queue::TimerQueue,
    Interrupt,
};
use heapless::binary_heap::Min;

pub mod clic;

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
            free_handles.push_back(h as u8).unwrap()
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

#[cfg(any(feature = "use-bheap", feature = "use-hwq"))]
pub type SwQueue<const Q_LEN: usize> = BHeap<Q_LEN>;

#[cfg(feature = "use-imap")]
pub type SwQueue<const Q_LEN: usize> = IMap<Q_LEN>;

pub struct VQueue<const Q_LEN: usize, const B_LEN: usize> {
    pub tq: bsp::timer_queue::TimerQueue,
    pub bq: heapless::Deque<Entry, B_LEN>,
    pub bq_dropq: heapless::FnvIndexSet<u8, B_LEN>,
    pub free_handles: heapless::Deque<u8, B_LEN>,
}

impl<const Q_LEN: usize, const B_LEN: usize> VQueue<Q_LEN, B_LEN> {
    pub fn new() -> Self {
        let tq = TimerQueue::init();

        let mut free_handles = heapless::Deque::new();
        let handle_bounds = tq.capacity()..(tq.capacity() + B_LEN as u32);
        for h in handle_bounds {
            free_handles.push_back(h as u8).unwrap()
        }

        Self {
            tq,
            bq: heapless::Deque::new(),
            bq_dropq: heapless::FnvIndexSet::new(),
            free_handles,
        }
    }
}

pub const UART_BAUD: u32 = if cfg!(feature = "rtl-tb") {
    1_500_000
} else {
    115_200
};

pub fn setup_irq(irq: Interrupt, level: u8) {
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}

/// Tear down the IRQ configuration to avoid side-effects for further testing
///
/// Copy and customize this function if you need more involved configurations.
pub fn tear_irq(irq: Interrupt) {
    Clic::ie(irq).disable();
    Clic::ctl(irq).set_level(0x0);
    Clic::attr(irq).set_shv(false);
    Clic::attr(irq).set_trig(Trig::Level);
    Clic::attr(irq).set_polarity(Polarity::Pos);
}

/// Print the name of the current file, i.e., test name.
///
/// This must be a macro to make sure core::file matches the file this is
/// invoked in.
#[macro_export]
macro_rules! print_example_name {
    () => {
        use bsp::sprintln;
        sprintln!("[{}]", core::file!());
    };
}

#[macro_export]
macro_rules! print_reg_u32 {
    ($reg:expr) => {
        use bsp::read_u32;
        sprintln!("{:#x}: {} \"{}\"", $reg, read_u32($reg), stringify!($reg));
    };
}

#[macro_export]
macro_rules! function {
    () => {{
        fn f() {}
        fn type_name_of<T>(_: T) -> &'static str {
            core::any::type_name::<T>()
        }
        let name = type_name_of(f);
        name.strip_suffix("::f").unwrap_unchecked()
    }};
}

/// Wraps [`bsp::timer_queue::Entry`] such that the same type can be used for
/// software priority queue as well.
#[cfg_attr(feature = "ufmt", derive(ufmt::derive::uDebug))]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
#[derive(Clone)]
pub struct Entry(pub bsp::timer_queue::Entry, pub u8);

impl Entry {
    #[inline(always)]
    pub fn with_handle(entry: bsp::timer_queue::Entry, handle: u8) -> Self {
        Self(entry, handle)
    }
}

impl ops::Deref for Entry {
    type Target = bsp::timer_queue::Entry;

    #[inline(always)]
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Eq for Entry {}

impl PartialEq for Entry {
    #[inline(always)]
    fn eq(&self, other: &Self) -> bool {
        self.0.ts == other.0.ts
    }
}

impl PartialOrd for Entry {
    #[inline(always)]
    fn partial_cmp(&self, other: &Self) -> Option<core::cmp::Ordering> {
        self.0.ts.partial_cmp(&other.0.ts)
    }
}

impl Ord for Entry {
    #[inline(always)]
    fn cmp(&self, other: &Self) -> core::cmp::Ordering {
        self.0.ts.cmp(&other.0.ts)
    }
}

/// Priority queue
///
/// Possibly virtualized.
pub trait PQueue {
    type Entry;

    /// Inserts an IRQ with a timestamp into the timer queue in one of the
    /// defined ways based on bench configuration.
    ///
    /// 1. use-hwq => inserts the entry into the long hardware queue
    /// 2. use-hwq + virtq => inserts the entry into the virtualized hardware
    ///    queue
    /// 3. - => inserts the entry into the software queue and programs t0 to
    ///    fire upon the most urgent entry
    ///
    /// # Safety
    ///
    /// Accesses timer queue in an unsynchronized way.
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8;
    fn drop(&mut self, handle: u8);
}

/// A queue with a software dispatch capability
pub trait Dispatch {
    /// Dispatches the hardward handler and sets up the timer for the next event
    fn dispatch(&mut self);
}

impl PQueue for bsp::timer_queue::TimerQueue {
    type Entry = bsp::timer_queue::Entry;

    #[inline(always)]
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| (self as &mut Self).push_rel(entry))
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| (self as &mut Self).drop(handle));
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
            (*self).queued = nq;
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
                let entry = Self::Entry { ts: ts, ..entry };

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

const MSG_BQ_OVF: &str = "backup queue overflow";

impl<const Q_LEN: usize, const B_LEN: usize> PQueue for VQueue<Q_LEN, B_LEN> {
    type Entry = bsp::timer_queue::Entry;

    #[inline(always)]
    fn enqueue_rel(&mut self, entry: Self::Entry) -> u8 {
        bsp::riscv::interrupt::free(|| {
            if !self.tq.is_full() {
                return self.tq.push_rel(entry);
            }

            // If queue is full, retrieve bottom element
            let btm = self.tq.drop(self.tq.btm_idx());

            let ts = bsp::mtimer::MTimer::instance().counter() + entry.ts;
            // If incoming is more urgent than 'bottom'
            if ts <= btm.ts {
                // Bottom => backup
                // Incoming => HW
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(btm.into(), h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));

                return self.tq.push_rel(entry);
            }
            // If bottom is more urgent than incoming
            else {
                // Bottom => HW
                // Incoming => backup
                self.tq.push_abs(btm);
                let h = unsafe { self.free_handles.pop_front().unwrap_unchecked() };
                self.bq
                    .push_back(Entry::with_handle(entry, h))
                    .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));
                return h;
            }
        })
    }

    #[inline(always)]
    fn drop(&mut self, handle: u8) {
        bsp::riscv::interrupt::free(|| {
            if (handle as usize) < Q_LEN {
                // Drop from main queue (HW)
                self.tq.drop(handle);
            } else {
                // Record element should be dropped from backup (virtual backup)
                unsafe { self.bq_dropq.insert(handle).unwrap_unchecked() };
            }
        })
    }
}
