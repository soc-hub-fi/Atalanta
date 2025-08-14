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
use heapless::{binary_heap::Min, Deque, FnvIndexSet};

pub mod clic;

#[cfg(any(feature = "use-bheap", feature = "use-hwq"))]
pub type SwQueue<const Q_LEN: usize> = heapless::BinaryHeap<Entry, Min, Q_LEN>;
#[cfg(feature = "use-imap")]
pub type SwQueue<const Q_LEN: usize> = heapless::FnvIndexMap<u8, Entry, Q_LEN>;

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
        name.strip_suffix("::f").unwrap()
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

const MSG_BQ_OVF: &str = "backup queue overflow";

/// Inserts an IRQ with a timestamp into the timer queue in one of the defined
/// ways based on bench configuration.
///
/// 1. use-hwq => inserts the entry into the long hardware queue
/// 2. use-hwq + virtq => inserts the entry into the virtualized hardware queue
/// 3. - => inserts the entry into the software queue
///
/// # Safety
///
/// Accesses timer queue in an unsynchronized way.
#[inline(always)]
pub unsafe fn abstract_insert<const Q_LEN: usize, const B_LEN: usize>(
    irq_id: u8,
    ofs: u64,
    swq: &mut SwQueue<Q_LEN>,
    free_handles: &mut Deque<u8, 256>,
    bq: &mut Deque<Entry, B_LEN>,
) -> u8 {
    // Software queue, no virtualization
    if cfg!(all(not(feature = "use-hwq"), not(feature = "virtq"))) {
        #[cfg(any(feature = "use-bheap", feature = "use-imap"))]
        let h = free_handles.pop_front().unwrap_unchecked();

        match () {
            #[cfg(feature = "use-bheap")]
            () => {
                swq.push_unchecked(Entry::with_handle(
                    bsp::timer_queue::Entry { ts: ofs, irq_id },
                    h,
                ));
            }
            #[cfg(feature = "use-imap")]
            () => swq
                .insert(
                    h,
                    Entry::with_handle(bsp::timer_queue::Entry { ts: ofs, irq_id }, h),
                )
                .unwrap_unchecked(),
            () => {
                unreachable!();
            }
        };
        #[cfg(any(feature = "use-bheap", feature = "use-imap"))]
        h
    }
    // Hardware queue, no virtualization
    else if cfg!(all(feature = "use-hwq", not(feature = "virtq"))) {
        tq_push_rel(irq_id, ofs)
    }
    // Hardware queue with virtualized backing queue
    else if cfg!(all(feature = "use-hwq", feature = "virtq")) {
        if !tq_is_full() {
            return tq_push_rel(irq_id, ofs);
        }

        // If queue is full, retrieve bottom element
        let mut tq = TimerQueue::instance();
        let btm = tq.drop(tq.btm_idx());

        let ts = bsp::mtimer::MTimer::instance().counter() + ofs;
        // If incoming is more urgent than 'bottom'
        if ts <= btm.ts {
            // Bottom => backup
            // Incoming => HW
            let h = free_handles.pop_front().unwrap_unchecked();
            bq.push_back(Entry::with_handle(btm.into(), h))
                .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));

            return tq_push_rel(irq_id, ofs);
        }
        // If bottom is more urgent than incoming
        else {
            // Bottom => HW
            // Incoming => backup
            TimerQueue::instance().push_abs(btm);
            let h = free_handles.pop_front().unwrap_unchecked();
            bq.push_back(Entry::with_handle(
                bsp::timer_queue::Entry::new(ts, irq_id),
                h,
            ))
            .unwrap_or_else(|_| panic!("{}", MSG_BQ_OVF));
            return h;
        }
    }
    // Software queue with virtualization (doesn't make sense)
    else {
        #[cfg(all(not(feature = "use-hwq"), feature = "virtq"))]
        compile_error!("virtualizing software queue makes no sense");
        unreachable!()
    }
}

//#[no_mangle]
#[inline(always)]
fn tq_push_rel(irq_id: u8, ofs: u64) -> u8 {
    let mut tq = unsafe { TimerQueue::instance() };
    let handle = tq.push_rel(bsp::timer_queue::Entry::new(ofs, irq_id).into());
    handle
}

/// Accesses timer queue in an unsynchronized way
#[inline(always)]
pub unsafe fn tq_is_full() -> bool {
    let tq = TimerQueue::instance();
    tq.is_full()
}

pub unsafe fn abstract_drop<const Q_LEN: usize, const B_LEN: usize>(
    drop_handle: u8,
    swq: &mut SwQueue<Q_LEN>,
    free_handles: &mut Deque<u8, 256>,
    bq: &mut Deque<Entry, B_LEN>,
    bq_dropq: &mut FnvIndexSet<u8, 256>,
) {
    // Software queue, no virtualization
    if cfg!(all(not(feature = "use-hwq"), not(feature = "virtq"))) {
        match () {
            #[cfg(feature = "use-bheap")]
            () => {
                let retain = swq
                    .into_iter()
                    .filter(|entry| entry.1 != drop_handle)
                    .cloned();
                let mut nq = SwQueue::new();
                for val in retain {
                    nq.push(val).unwrap_unchecked();
                }
                *swq = nq;
            }
            #[cfg(feature = "use-imap")]
            () => swq.remove(&drop_handle),
            () => unreachable!(),
        };
    }
    // Hardware queue, no virtualization
    else if cfg!(all(feature = "use-hwq", not(feature = "virtq"))) {
        let mut tq = TimerQueue::instance();
        tq.drop(drop_handle);
    }
    // Hardware queue with virtualized backing queue
    else if cfg!(all(feature = "use-hwq", feature = "virtq")) {
        if (drop_handle as usize) < Q_LEN {
            // Drop from main queue (HW)
            let mut tq = TimerQueue::instance();
            tq.drop(drop_handle);
        } else {
            // Record element should be dropped from backup (virtual backup)
            bq_dropq.insert(drop_handle).unwrap_unchecked();
        }
    }
    // Software queue with virtualization (doesn't make sense)
    else {
        #[cfg(all(not(feature = "use-hwq"), feature = "virtq"))]
        compile_error!("virtualizing software queue makes no sense");
        unreachable!()
    }
}
