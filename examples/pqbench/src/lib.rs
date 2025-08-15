#![no_std]
#![no_main]

#[cfg(not(any(feature = "use-hwq", feature = "use-imap", feature = "use-bheap")))]
compile_error!("must select `use-hwq`, `use-imap`, or `use-bheap`");

#[cfg(feature = "use-bheap")]
mod bheap;
#[cfg(feature = "use-hwq")]
mod hwq;
#[cfg(feature = "use-imap")]
mod imap;
#[cfg(feature = "virtq")]
mod vqueue;

use core::ops;

use bsp::{
    clic::{Clic, Polarity, Trig},
    Interrupt,
};

#[cfg(feature = "use-bheap")]
pub use bheap::BHeap;
#[cfg(feature = "use-imap")]
pub use imap::IMap;
#[cfg(feature = "virtq")]
pub use vqueue::VQueue;

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
