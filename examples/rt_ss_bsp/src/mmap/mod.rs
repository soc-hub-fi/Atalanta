//! Memory maps for rt-ss
//!
//! Based on <src/ip/rt_pkg.sv>.

// Some addresses are given in functional style but use all-caps for consistency
#![allow(non_snake_case)]
// Identity ops can improve clarity for memory maps
#![allow(clippy::identity_op)]

mod clic;
mod timer;
mod uart;
mod spi;

pub use clic::*;
pub use timer::*;
pub use uart::*;
pub use spi::*;

pub const DEBUG_ADDR: usize = 0x0;
pub const LED_ADDR: usize = 0x3_0008;
