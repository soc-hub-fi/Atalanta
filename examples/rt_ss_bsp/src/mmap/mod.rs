//! Memory maps for rt-ss

// Some addresses are given in functional style but use all-caps for consistency
#![allow(non_snake_case)]
// Identity ops can improve clarity for memory maps
#![allow(clippy::identity_op)]

mod clic;
mod timer;
mod uart;

pub use clic::*;
pub use timer::*;
pub use uart::*;

pub const LED_ADDR: usize = 0x3_0008;
