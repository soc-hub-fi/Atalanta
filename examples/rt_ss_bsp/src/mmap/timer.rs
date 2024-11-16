//! Memory maps for mtimer
pub const TIMER_BASE: usize = 0x30200;

pub const MTIME_LOW_ADDR: usize = TIMER_BASE + 0;
pub const MTIME_HIGH_ADDR: usize = TIMER_BASE + 4;
pub const MTIMECMP_LOW_ADDR: usize = TIMER_BASE + 8;
pub const MTIMECMP_HIGH_ADDR: usize = TIMER_BASE + 12;
pub const MTIME_CTRL_ADDR: usize = TIMER_BASE + 16;
