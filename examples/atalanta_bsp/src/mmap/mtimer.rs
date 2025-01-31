//! Memory maps for mtimer (RISC-V base ISA)
//!
//! mtimer is implemented by:
//!
//! - [timer_core (SV)](.../src/ip/timer_core.sv)
//! - [apb_mtimer (SV)](.../src/ip/apb_mtimer.sv)
//!
//! See also [crate::mmap::timer_group] for the general purpose timer group.
pub const MTIMER_BASE: usize = 0x3_0200;

pub const MTIME_LOW_ADDR_OFS: usize = 0;
pub const MTIME_HIGH_ADDR_OFS: usize = 4;
pub const MTIMECMP_LOW_ADDR_OFS: usize = 8;
pub const MTIMECMP_HIGH_ADDR_OFS: usize = 12;
pub const MTIME_CTRL_ADDR_OFS: usize = 16;
