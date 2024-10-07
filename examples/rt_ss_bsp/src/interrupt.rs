use core::arch::asm;

use crate::clic::InterruptNumber;

#[derive(Clone, Copy, PartialEq)]
#[repr(u16)]
#[cfg_attr(not(feature = "ufmt"), derive(Debug))]
pub enum Interrupt {
    // SupervisorSoft = 1,
    MachineSoft = 3,
    // SupervisorTimer = 5,
    MachineTimer = 7,
    // SupervisorExternal = 9,
    MachineExternal = 11,
    /// Placeholder for testing
    Sixteen = 16,
    /// Placeholder for testing
    Seventeen = 17,
    // Reserved for clint NMI
    // Nmi = 31,
}

unsafe impl InterruptNumber for Interrupt {
    const MAX_INTERRUPT_NUMBER: u16 = 255;

    fn number(self) -> u16 {
        self as u16
    }

    fn from_number(value: u16) -> Result<Self, u16> {
        match value {
            3 => Ok(Self::MachineSoft),
            7 => Ok(Self::MachineTimer),
            11 => Ok(Self::MachineExternal),
            16 => Ok(Self::Sixteen),
            17 => Ok(Self::Seventeen),
            _ => Err(value),
        }
    }
}

/// Allows nested interrupts to occur during closure execution
///
/// # Safety
///
/// - Do not call this function inside a critical section.
/// - This method is assumed to be called within an interrupt handler.
/// - Make sure to clear the interrupt flag that caused the interrupt before
///   calling this method. Otherwise, the interrupt will be re-triggered before
///   executing `f`.
#[inline]
pub unsafe fn nested<F, R>(f: F) -> R
where
    F: FnOnce() -> R,
{
    asm!(
        "addi sp, sp, -(4 * 2)",
        "csrr t0, mcause",
        "csrr t1, mepc",
        "sw t0, 0(sp)",
        "sw t1, 4(sp)",
    );

    // enable interrupts to allow nested interrupts
    riscv::interrupt::enable();

    let r: R = f();

    riscv::interrupt::disable();

    asm!(
        "lw t0, 0(sp)",
        "lw t1, 4(sp)",
        "csrw mcause, t0",
        "csrw mepc, t1",
        "addi sp, sp, (4 * 2)",
    );

    r
}
