pub const CFG_BASE: usize = 0x3_0500;

/// # Safety
///
/// Setting periph clk div will mess up timings for currently configured
/// peripherals, so make sure to set this before configuring the peripherals, or
/// make sure to reconfigure them.
pub const PERIPH_CLK_DIV_OFS: usize = 0x0;
