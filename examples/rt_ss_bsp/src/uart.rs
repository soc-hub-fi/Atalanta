//! Implementation of [PULP APB UART](https://github.com/pulp-platform/apb_uart/) (v0.2.1)
//!
//! PULP APB UART conforms to the NS16550.
use crate::{mask_u8, mmap::*, unmask_u8};
use crate::{read_u8, write_u8};

// Hack to cover some more error cases with outputful panics
#[cfg(any(all(feature = "fpga", feature = "rt"), feature = "panic"))]
pub(crate) static mut UART_IS_INIT: bool = false;

/// When to raise a UART interrupt
#[derive(Clone)]
#[repr(u8)]
pub enum UartInterrupt {
    /// Interrupt is raised when...
    ///
    /// * (fifo disabled) received data is available
    /// * (fifo enabled) trigger level has been reached (sa. [UART_IIR_FCR_OFS])
    /// * character timeout has been reached error or break interrupt
    OnData = 0b1,
    /// Interrupt is raised when [UART_RBR_THR_DLL_OFS] is empty, i.e., when
    /// character has been consumed by polling.
    OnEmpty = 0b1 << 1,
    /// Interrupt is raised on overrun error, parity error, framing error or
    /// break interrupt
    OnError = 0b1 << 2,
}

/// HAL driver for PULP APB UART
///
/// The type parameter represents the base address for the UART.
pub struct ApbUart;

impl ApbUart {
    /// # Parameters
    ///
    /// * `freq` - SoC frequency, used to calculate BAUD rate together with a
    ///   divisor
    /// * `baud` - target BAUD (sa. UART protocol)
    #[inline]
    pub fn init(freq: u32, baud: u32) -> ApbUart {
        // This is the hardware default value; it could be made configurable
        const PERIPH_CLK_DIV: u32 = 2;
        let divisor: u32 = freq / PERIPH_CLK_DIV / (baud << 4);

        // Safety: all UART registers are 4-byte aligned which makes the below writes
        // always valid
        unsafe {
            // Disable all interrupts
            write_u8(UART_IER_DLM, 0x00);

            // Enable DLAB (set baud rate divisor)
            mask_u8(UART_LCR, 0x80);
            // Divisor (lo byte)
            write_u8(UART_DLAB_LSB, divisor as u8);
            // Divisor (hi byte)
            write_u8(UART_DLAB_MSB, (divisor >> 8) as u8);
            // 8 bits, no parity, one stop bit
            write_u8(UART_LCR, UartLcrDataBits::Bits8 as u8);
            // Restore DLAB state
            unmask_u8(UART_LCR, UART_LCR_DLAB_BIT);

            write_u8(
                UART_IIR_FCR,
                // Enable FIFO
                UART_FCR_FIFO_EN_BIT
                    // Clear RX & TX
                    | UART_FCR_FIFO_RX_RESET_BIT
                    | UART_FCR_FIFO_TX_RESET_BIT
                    // 14-byte threshold
                    | UART_FCR_TRIG_RX_LSB
                    | UART_FCR_TRIG_RX_MSB,
            );
            // Autoflow mode
            write_u8(UART_MCR, 0x20);
        }

        #[cfg(any(all(feature = "fpga", feature = "rt"), feature = "panic"))]
        unsafe {
            UART_IS_INIT = true
        };

        Self {}
    }

    /// # Safety
    ///
    /// Returns a potentially uninitialized instance of APB UART. On ASIC, make
    /// sure to call [ApbUart::init] prior to this call, otherwise the UART
    /// won't behave properly.
    pub const unsafe fn instance() -> Self {
        Self {}
    }

    #[inline]
    pub fn write(&mut self, buf: &[u8]) {
        for b in buf {
            self.putc(*b);
        }
    }

    #[inline]
    pub fn write_str(&mut self, s: &str) {
        self.write(s.as_bytes());
    }

    /// Flush this output stream, blocking until all intermediately buffered
    /// contents reach their destination.
    #[inline]
    pub fn flush(&mut self) {
        // Wait for hardware to report completion
        while !self.is_transmit_empty() {}
    }

    #[inline]
    fn putc(&mut self, c: u8) {
        while !self.is_transmit_empty() {}
        // Safety: UART_THR is 4-byte aligned
        unsafe { write_u8(UART_RBR_THR_DLL, c) };
    }

    #[inline]
    pub fn getc(&mut self) -> u8 {
        // Wait for data to become ready
        while unsafe { read_u8(UART_LSR) } & UART_LSR_RX_FIFO_VALID_BIT == 0 {}

        // SAFETY: UART0_ADDR is 4-byte aligned
        unsafe { read_u8(UART_BASE) }
    }

    #[inline]
    fn is_transmit_empty(&self) -> bool {
        // Safety: UART_LINE_STATUS is 4-byte aligned
        unsafe { (read_u8(UART_LSR) & 0x20) != 0 }
    }
}
