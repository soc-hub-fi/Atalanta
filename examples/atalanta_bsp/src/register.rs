//! Unified access to base ISA CSRs + Ibex/Atalanta specific CSRs
//!
//! * [Ibex register documentation](https://ibex-core.readthedocs.io/en/latest/03_reference/cs_registers.html)

// Re-export base ISA registers
pub use crate::riscv::register::*;

/// Insert a new value into a bitfield
///
/// `value` is masked to `width` bits and inserted into `orig`.`
#[inline]
pub fn bf_insert(orig: usize, bit: usize, width: usize, value: usize) -> usize {
    let mask = (1 << width) - 1;
    orig & !(mask << bit) | ((value & mask) << bit)
}

/// Extract a value from a bitfield
///
/// Extracts `width` bits from bit offset `bit` and returns it shifted to bit
/// 0.s
#[inline]
pub fn bf_extract(orig: usize, bit: usize, width: usize) -> usize {
    let mask = (1 << width) - 1;
    (orig >> bit) & mask
}

pub mod mconfigptr {
    use riscv::read_csr_as_usize;

    // Supported operations
    read_csr_as_usize!(0xF15);
}

pub mod mtvt {
    use riscv::{clear, read_csr_as, set, write_csr};

    /// Trap mode
    #[derive(Copy, Clone, Eq, PartialEq)]
    #[cfg_attr(feature = "ufmt", derive(crate::ufmt::derive::uDebug))]
    #[cfg_attr(not(feature = "ufmt"), derive(Debug))]
    pub enum TrapMode {
        Direct = 0,
        Vectored = 1,
        Clic = 0b11,
    }

    /// mtvt register
    #[derive(Clone, Copy)]
    #[cfg_attr(feature = "ufmt", derive(crate::ufmt::derive::uDebug))]
    #[cfg_attr(not(feature = "ufmt"), derive(Debug))]
    pub struct Mtvt {
        bits: usize,
    }

    impl From<usize> for Mtvt {
        #[inline]
        fn from(bits: usize) -> Self {
            Self { bits }
        }
    }

    impl Mtvt {
        /// Returns the contents of the register as raw bits
        #[inline]
        pub fn bits(&self) -> usize {
            self.bits
        }

        /// Returns the trap-vector base-address
        #[inline]
        pub fn address(&self) -> usize {
            self.bits - (self.bits & 0b11)
        }

        /// Returns the trap-vector mode
        #[inline]
        pub fn trap_mode(&self) -> Option<TrapMode> {
            let mode = self.bits & 0b11;
            match mode {
                0 => Some(TrapMode::Direct),
                1 => Some(TrapMode::Vectored),
                0b11 => Some(TrapMode::Clic),
                _ => None,
            }
        }
    }

    // # Supported operations

    // Bring in `_write` for `write`
    write_csr!(0x307);

    /// Writes the CSR
    #[inline]
    pub unsafe fn write(addr: usize, mode: TrapMode) {
        let bits = addr + mode as usize;
        _write(bits);
    }

    read_csr_as!(Mtvt, 0x307);
    set!(0x307);
    clear!(0x307);
}

// If U-mode is not supported, then registers menvcfg and menvcfgh do not exist.
/*
pub mod menvcfg;
pub mod menvcfgh
*/

// # CLIC registers

pub mod mnxti {
    use riscv::{clear, read_csr_as, set, write_csr_as};

    /// mnxti register
    ///
    /// The mnxti CSR is used by software to improve the performance of handling
    /// back-to-back software vectored interrupts. It does this by avoiding the
    /// overhead of additional interrupt pipeline flushes and redundant context
    /// save/restore for these back-to-back software vectored interrupts. The
    /// mnxti CSR is intended to be used inside an interrupt handler after an
    /// initial interrupt has been taken and mcause and mepc registers have been
    /// updated with the interrupted context and the id of the interrupt.
    #[derive(Clone, Copy)]
    #[cfg_attr(feature = "ufmt", derive(crate::ufmt::derive::uDebug))]
    #[cfg_attr(not(feature = "ufmt"), derive(Debug))]
    pub struct Mnxti {
        bits: usize,
    }

    impl From<usize> for Mnxti {
        #[inline]
        fn from(bits: usize) -> Self {
            Self { bits }
        }
    }

    impl Mnxti {
        /// Returns the contents of the register as raw bits
        #[inline]
        pub fn bits(&self) -> usize {
            self.bits
        }
    }

    read_csr_as!(Mnxti, 0x345);
    write_csr_as!(Mnxti, 0x345);
    set!(0x345);
    clear!(0x345);
}

pub mod mintstatus {
    use riscv::read_csr_as;

    use super::bf_extract;

    /// mintstatus register
    ///
    /// Holds the active interrupt level for each supported privilege mode.
    /// These fields are read-only. The primary reason to expose these
    /// fields is to support debug.
    #[derive(Clone, Copy)]
    #[cfg_attr(feature = "ufmt", derive(crate::ufmt::derive::uDebug))]
    #[cfg_attr(not(feature = "ufmt"), derive(Debug))]
    pub struct Mintstatus {
        bits: usize,
    }

    impl From<usize> for Mintstatus {
        #[inline]
        fn from(bits: usize) -> Self {
            Self { bits }
        }
    }

    impl Mintstatus {
        /// Returns the contents of the register as raw bits
        #[inline]
        pub fn bits(&self) -> usize {
            self.bits
        }

        /// Machine Interrupt Level
        #[inline]
        pub fn mil(&self) -> usize {
            bf_extract(self.bits, 31, 24)
        }

        // if ssclic is supported
        /*
        #[inline]
        pub fn sil(&self) -> usize {
            bf_extract(self.bits, 15, 8)
        }
        */
    }

    read_csr_as!(Mintstatus, 0x346);
}

pub mod mintthresh {
    use riscv::{clear, read_csr_as, set};

    /// mintthresh register
    ///
    /// Holds an 8-bit field (th) for the threshold level of the associated
    /// privilege mode. The th field is held in the least-significant 8 bits of
    /// the CSR, and zero should be written to the upper bits.
    ///
    /// A typical usage of the interrupt-level threshold is for implementing
    /// critical sections. The current handler can temporarily raise its
    /// effective interrupt level to implement a critical section among a subset
    /// of levels, while still allowing higher interrupt levels to preempt.
    ///
    /// The current hart’s effective interrupt level would then be:
    /// effective_level = max(mintstatus.mil`, mintthresh.th)
    ///
    /// The max is used to prevent a hart from dropping below its original level
    /// which would break assumptions in design, and also makes it simple for
    /// software to remove threshold without knowing its own level by simply
    /// setting mintthresh to the lowest supported mintthresh value.
    ///
    /// The interrupt-level threshold is only valid when running in associated
    /// privilege mode and not in other modes. This is because interrupts for
    /// lower privilege modes are always disabled, whereas interrupts for higher
    /// privilege modes are always enabled.
    #[derive(Clone, Copy)]
    #[cfg_attr(feature = "ufmt", derive(crate::ufmt::derive::uDebug))]
    #[cfg_attr(not(feature = "ufmt"), derive(Debug))]
    pub struct Mintthresh {
        bits: usize,
    }

    impl From<usize> for Mintthresh {
        #[inline]
        fn from(bits: usize) -> Self {
            Self { bits }
        }
    }

    impl Mintthresh {
        /// Returns the contents of the register as raw bits
        #[inline]
        pub fn bits(&self) -> usize {
            self.bits
        }
    }

    read_csr_as!(Mintthresh, 0x347);

    /// Writes the CSR and returns the previous value
    #[inline]
    pub fn write(value: Mintthresh) -> usize {
        let pvalue: usize;
        unsafe { core::arch::asm!("csrrw {0}, 0x347, {1}", out(reg) pvalue, in(reg) value.bits) }
        pvalue
    }

    set!(0x347);
    clear!(0x347);
}

// mscratchsw, mscratchswl are useful for multi-privilege only
/*
pub mod mscratchsw;
pub mod mscratchswl;
*/

pub mod mclicbase {
    use riscv::read_csr_as_usize;

    // Supported operations
    read_csr_as_usize!(0x350);
}

// # CLIC registers end

// # Debug registers

/*
CSR_SCONTEXT  = 12'h5A8,

// ePMP control
CSR_MSECCFG   = 12'h747,
CSR_MSECCFGH  = 12'h757,

// Debug trigger
CSR_TSELECT   = 12'h7A0,
CSR_TDATA1    = 12'h7A1,
CSR_TDATA2    = 12'h7A2,
CSR_TDATA3    = 12'h7A3,
CSR_MCONTEXT  = 12'h7A8,
CSR_MSCONTEXT = 12'h7AA,

// Debug/trace
CSR_DCSR      = 12'h7b0,
CSR_DPC       = 12'h7b1,

// Debug
CSR_DSCRATCH0 = 12'h7b2, // optional
CSR_DSCRATCH1 = 12'h7b3, // optional
*/
// # Debug registers end

pub mod cpuctrlsts {
    //! CPU Control and Status Register (Ibex Custom CSR)

    use riscv::read_csr_as_usize;

    // Supported operations
    read_csr_as_usize!(0x7C0);
}

pub mod secureseed {
    //! Security feature random seed (Ibex Custom CSR)

    use riscv::read_csr_as_usize;

    // Supported operations
    read_csr_as_usize!(0x7C1);
}
