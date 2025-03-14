// Allowed for extra clarity in certain cases
#![allow(clippy::identity_op)]

//! CLIC interrupt enable register.
use riscv_peripheral::common::{Reg, RW};

/// CLIC interrupt enable register.
///
/// Each interrupt input has a dedicated interrupt-enable bit (`clicintie[i]`)
/// and occupies one byte in the memory map for ease of access. This control bit
/// is read-write to enable/disable the corresponding interrupt. The enable bit
/// is located in bit 0 of the byte. Software should assume `clicintie[i] = 0`
/// means no interrupt enabled, and `clicintie[i] != 0` indicates an interrupt
/// is enabled to accommodate possible future expansion of the clicintie field.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(transparent)]
pub struct INTIE {
    ptr: *mut u32,
}

impl INTIE {
    const INTIE_OFFSET: usize = 0x1;

    /// Creates a new interrupt enable register
    ///
    /// # Safety
    ///
    /// The base address must point to a valid 32-bit clicintx register cluster.
    #[inline]
    pub(crate) const unsafe fn new(addr: usize) -> Self {
        Self {
            ptr: addr as *mut _,
        }
    }

    /// Checks if an interrupt source is enabled.
    #[inline]
    pub fn is_enabled(self) -> bool {
        // SAFETY: valid interrupt number
        let reg: Reg<u32, RW> = unsafe { Reg::new(self.ptr) };

        // > Software should assume `clicintie[i] = 0` means no interrupt enabled, and
        // > `clicintie[i] != 0`
        // > indicates an interrupt is enabled to accommodate possible future expansion
        // > of the
        // > clicintie field.
        reg.read_bit(0 + 8 * Self::INTIE_OFFSET)
    }

    /// Enables an interrupt source.
    ///
    /// # Safety
    ///
    /// * Enabling an interrupt source can break mask-based critical sections.
    #[inline]
    pub unsafe fn enable(self) {
        // SAFETY: valid interrupt number
        let reg: Reg<u32, RW> = unsafe { Reg::new(self.ptr) };

        // > The enable bit is located in bit 0 of the byte.
        reg.set_bit(0 + 8 * Self::INTIE_OFFSET);
    }

    /// Disables an interrupt source.
    #[inline]
    pub fn disable(self) {
        // SAFETY: valid interrupt number
        let reg: Reg<u32, RW> = unsafe { Reg::new(self.ptr) };

        // > The enable bit is located in bit 0 of the byte.
        reg.clear_bit(0 + 8 * Self::INTIE_OFFSET);
    }

    /// Sets the interrupt source as PCS or not
    #[inline]
    pub fn set_pcs(self, set_pcs: bool) {
        // SAFETY: valid interrupt number
        let reg: Reg<u32, RW> = unsafe { Reg::new(self.ptr) };

        // The PCS enable bit is located in bit 4 of the byte.
        if set_pcs {
            reg.set_bit(4 + 8 * Self::INTIE_OFFSET);
        } else {
            reg.clear_bit(4 + 8 * Self::INTIE_OFFSET);
        }
    }
}
