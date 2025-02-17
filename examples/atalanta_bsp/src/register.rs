//! Unified access to base ISA CSRs + Ibex/Atalanta specific CSRs

// Re-export base ISA registers
pub use crate::riscv::register::*;

pub mod mintthresh {
    use riscv::{clear, read_csr_as, set, write_csr_as};

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
    write_csr_as!(Mintthresh, 0x347);
    set!(0x347);
    clear!(0x347);
}
