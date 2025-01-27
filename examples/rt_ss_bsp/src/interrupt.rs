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
    /// UART interrupt (Non-standard, overrides S-mode software interrupt
    /// mapping.)
    Uart = 17,
    Gpio = 18,
    SpiRxTxIrq = 19,
    /// SPI end of transmission
    SpiEotIrq = 20,
    /// Timer 0 overflow
    Timer0Ovf = 21,
    /// Timer 0 compare
    Timer0Cmp = 22,
    /// Timer1 overflow
    Timer1Ovf = 23,
    /// Timer1 compare
    Timer1Cmp = 24,
    /// Timer2 overflow
    Timer2Ovf = 25,
    /// Timer2 compare
    Timer2Cmp = 26,
    /// Timer3 overflow
    Timer3Ovf = 27,
    /// Timer3 compare
    Timer3Cmp = 28,
    /// Non-maskable interrupt, carried over from standard Ibex
    Nmi = 31,
    Dma0 = 32,
    Dma1 = 33,
    Dma2 = 34,
    Dma3 = 35,
    Dma4 = 36,
    Dma5 = 37,
    Dma6 = 38,
    Dma7 = 39,
    Dma8 = 40,
    Dma9 = 41,
    Dma10 = 42,
    Dma11 = 43,
    Dma12 = 44,
    Dma13 = 45,
    Dma14 = 46,
    Dma15 = 47,
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
            17 => Ok(Self::Uart),
            32 => Ok(Self::Dma0),
            33 => Ok(Self::Dma1),
            34 => Ok(Self::Dma2),
            35 => Ok(Self::Dma3),
            36 => Ok(Self::Dma4),
            37 => Ok(Self::Dma5),
            38 => Ok(Self::Dma6),
            39 => Ok(Self::Dma7),
            40 => Ok(Self::Dma8),
            41 => Ok(Self::Dma9),
            42 => Ok(Self::Dma10),
            43 => Ok(Self::Dma11),
            44 => Ok(Self::Dma12),
            45 => Ok(Self::Dma13),
            46 => Ok(Self::Dma14),
            47 => Ok(Self::Dma15),

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
