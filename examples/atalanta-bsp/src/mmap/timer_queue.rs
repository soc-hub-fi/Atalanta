pub const TIMER_QUEUE_BASE: usize = 0x4_0000;

#[repr(C)]
pub struct RegisterBlock {
    /// * `[0]` - full
    /// * `[8]` - empty
    pub status: u32,
    /// Handle ("index") to the last pushed entry
    pub last_idx: u32,
    /// Handle ("index") to the topmost entry
    pub top_idx: u32,
    /// Handle ("index") to the bottom entry
    pub btm_idx: u32,
    /// Push/drop control
    ///
    /// * `[24..=31]`   - drop handle ("index")
    /// * `[16..=23]`   - payload value
    /// * `[8]`         - drop trigger (auto-pulled down by HW)
    /// * `[0]`         - push trigger (auto-pulled down by HW)
    pub pd_ctrl: u32,
    /// Relative timestamp for push operation (low bits)
    pub p_rel_lo: u32,
    /// Relative timestamp for push operation (high bits)
    pub p_rel_hi: u32,
    /// Absolute timestamp for push operation (low bits)
    pub p_abs_lo: u32,
    /// Absolute timestamp for push operation (high bits)
    pub p_abs_hi: u32,
}

pub const TIMER_QUEUE: *mut RegisterBlock = TIMER_QUEUE_BASE as *mut _;
