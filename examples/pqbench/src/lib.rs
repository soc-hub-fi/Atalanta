#![no_std]
#![no_main]

use bsp::{
    clic::{Clic, InterruptNumber, Polarity, Trig},
    sprintln,
    timer_queue::TimerQueue,
    Interrupt,
};

pub mod clic;

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
    sprintln!("Tear {:?} (id = {})", irq, irq.number());
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

/// Accesses timer queue in an unsynchronized way
pub unsafe fn hw_pq_push_rel(irq_id: u8, ofs: u64) -> u8 {
    let mut tq = TimerQueue::instance();
    tq.push_rel(bsp::timer_queue::Entry::new(ofs, irq_id).into())
}

/// Accesses timer queue in an unsynchronized way
pub unsafe fn hw_pq_is_full() -> bool {
    let tq = TimerQueue::instance();
    tq.is_full()
}

/// Wraps [`bsp::timer_queue::Entry`] such that the same type can be used for
/// software priority queue as well.
pub struct Entry(bsp::timer_queue::Entry);

impl From<bsp::timer_queue::Entry> for Entry {
    fn from(value: bsp::timer_queue::Entry) -> Self {
        Self(value)
    }
}

impl Eq for Entry {}

impl PartialEq for Entry {
    fn eq(&self, other: &Self) -> bool {
        self.0.ts == other.0.ts
    }
}

impl PartialOrd for Entry {
    fn partial_cmp(&self, other: &Self) -> Option<core::cmp::Ordering> {
        self.0.ts.partial_cmp(&other.0.ts)
    }
}

impl Ord for Entry {
    fn cmp(&self, other: &Self) -> core::cmp::Ordering {
        self.0.ts.cmp(&other.0.ts)
    }
}
