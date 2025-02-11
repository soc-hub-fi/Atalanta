//! Core-Local Interrupt Controller (CLIC) peripheral.
//!
//! This CLIC uses the now obsolete MMIO interface. This may not match the new
//! specification, available here: <https://github.com/riscv/riscv-fast-interrupt/blob/master/clic.adoc>
pub mod intattr;
pub mod intctl;
pub mod intie;
pub mod intip;
pub mod inttrig;
pub mod smclicconfig;

pub use intattr::{Polarity, Trig};
// Re-export useful riscv-pac traits
pub use riscv_pac::{HartIdNumber, InterruptNumber, PriorityNumber};

/// Core-Local Interrupt Controller (CLIC) peripheral.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Clic;

pub type CLIC = Clic;

impl Clic {
    const BASE: usize = crate::mmap::CLIC_BASE_ADDR;

    const SMCLICCONFIG_OFFSET: usize = 0x0;

    const INTTRIG_OFFSET: usize = 0x40;
    const INTTRIG_SEPARATION: usize = 0x4;

    const INT_OFFSET: usize = 0x1000;
    const INT_SEPARATION: usize = 0x4;

    /// Returns the smclicconfig register of the CLIC.
    #[inline]
    pub fn smclicconfig() -> smclicconfig::SMCLICCONFIG {
        // SAFETY: valid address
        unsafe { smclicconfig::SMCLICCONFIG::new(Self::BASE + Self::SMCLICCONFIG_OFFSET) }
    }

    /// Returns the clicinttrig register for a given interrupt number.
    #[inline]
    pub fn inttrig<I: InterruptNumber>(int_nr: I) -> inttrig::INTTRIG {
        let addr =
            Self::BASE + Self::INTTRIG_OFFSET + int_nr.number() as usize * Self::INTTRIG_SEPARATION;
        // SAFETY: valid address
        unsafe { inttrig::INTTRIG::new(addr) }
    }

    /// Returns the interrupts pending register of a given interrupt number.
    #[inline]
    pub fn ip<I: InterruptNumber>(int_nr: I) -> intip::INTIP {
        let addr = Self::BASE + Self::INT_OFFSET + int_nr.number() as usize * Self::INT_SEPARATION;
        // SAFETY: valid address
        unsafe { intip::INTIP::new(addr) }
    }

    /// Returns the interrupts enable register of a given interrupt number.
    #[inline]
    pub fn ie<I: InterruptNumber>(int_nr: I) -> intie::INTIE {
        let addr = Self::BASE + Self::INT_OFFSET + int_nr.number() as usize * Self::INT_SEPARATION;
        // SAFETY: valid interrupt_number
        unsafe { intie::INTIE::new(addr) }
    }

    /// Returns the attribute register of a given interrupt number.
    #[inline]
    pub fn attr<I: InterruptNumber>(int_nr: I) -> intattr::INTATTR {
        let addr = Self::BASE + Self::INT_OFFSET + int_nr.number() as usize * Self::INT_SEPARATION;
        // SAFETY: valid address
        unsafe { intattr::INTATTR::new(addr) }
    }

    /// Returns the control register of this interrupt.
    #[inline]
    pub fn ctl<I: InterruptNumber>(int_nr: I) -> intctl::INTCTL {
        let addr = Self::BASE + Self::INT_OFFSET + int_nr.number() as usize * Self::INT_SEPARATION;
        // SAFETY: valid address
        unsafe { intctl::INTCTL::new(addr) }
    }
}
