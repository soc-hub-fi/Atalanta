//! Implementation of [PULP APB UART](https://github.com/pulp-platform/apb_uart/) (v0.2.1)
//!
//! PULP APB UART conforms to the NS16550.
use crate::mmap::*;
use crate::{read_u8, write_u8};

// Hack to cover some more error cases with outputful panics
#[cfg(any(all(feature = "fpga", feature = "rt"), feature = "panic"))]
pub(crate) static mut UART_IS_INIT: bool = false;

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
        const PERIPH_CLK_DIV: u32 = 2;
        let divisor: u32 = freq / PERIPH_CLK_DIV / (baud << 4);

        // Safety: all UART registers are 4-byte aligned which makes the below writes
        // always valid
        unsafe {
            // Disable all interrupts
            write_u8(UART_IER_DLM, 0x00);
            // Enable DLAB (set baud rate divisor)
            write_u8(UART_LCR, 0x80);
            // Divisor (lo byte)
            write_u8(UART_DLAB_LSB, divisor as u8);
            // Divisor (hi byte)
            write_u8(UART_DLAB_MSB, (divisor >> 8) as u8);
            // 8 bits, no parity, one stop bit
            write_u8(UART_LCR, 0x03);
            // Enable FIFO, clear them, with 14-byte threshold
            write_u8(UART_IIR_FCR, 0xC7);
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
    pub fn write_str(&mut self, s: &str) {
        for c in s.bytes() {
            self.putc(c);
        }
    }

    #[inline]
    fn putc(&mut self, c: u8) {
        while !self.is_transmit_empty() {}
        // Safety: UART_THR is 4-byte aligned
        unsafe { write_u8(UART_RBR_THR_DLL, c) };
    }

    #[inline]
    fn is_transmit_empty(&self) -> bool {
        // Safety: UART_LINE_STATUS is 4-byte aligned
        unsafe { (read_u8(UART_LSR) & 0x20) != 0 }
    }
}
