//! Implementation of [PULP APB UART](https://github.com/pulp-platform/apb_uart/) (v0.2.1)
//!
//! PULP APB UART conforms to the NS16550.
use embedded_io::Write;

use crate::{mask_u8, mmap::*, read_u8_masked, unmask_u8};
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
    /// Interrupt is raised when character has been consumed by polling, i.e.,
    /// when [UART_RBR_THR_DLL_OFS] is empty.
    OnEmpty = 0b1 << 1,
    /// Interrupt is raised on overrun error, parity error, framing error or
    /// break interrupt
    OnError = 0b1 << 2,
}

/// Relocatable HAL driver for PULP APB UART
///
/// The type parameter represents the base address for the UART.
pub struct ApbUartHal<const BASE_ADDR: usize>;

/// [ApbUartHal]
pub type ApbUart = ApbUartHal<UART_BASE>;

impl<const BASE_ADDR: usize> ApbUartHal<BASE_ADDR> {
    /// # Parameters
    ///
    /// * `freq` - SoC frequency, used to calculate BAUD rate together with a
    ///   divisor
    /// * `baud` - target BAUD (sa. UART protocol)
    #[inline]
    pub fn init(freq: u32, baud: u32) -> Self {
        // Safety: all UART registers are 4-byte aligned which makes the below writes
        // always valid
        unsafe {
            // Read current peripheral clock divider
            let periph_clk_div = read_u8_masked(CFG_BASE + PERIPH_CLK_DIV_OFS, 0xf);
            let divisor: u32 = freq / periph_clk_div as u32 / (baud << 4);

            // Disable all interrupts
            write_u8(BASE_ADDR + UART_IER_DLM_OFS, 0x00);

            // Enable DLAB (set baud rate divisor)
            mask_u8(BASE_ADDR + UART_LCR_OFS, 0x80);
            // Divisor (lo byte)
            write_u8(BASE_ADDR + UART_DLAB_LSB_OFS, divisor as u8);
            // Divisor (hi byte)
            write_u8(BASE_ADDR + UART_DLAB_MSB_OFS, (divisor >> 8) as u8);
            // 8 bits, no parity, one stop bit
            write_u8(BASE_ADDR + UART_LCR_OFS, UartLcrDataBits::Bits8 as u8);
            // Restore DLAB state
            unmask_u8(BASE_ADDR + UART_LCR_OFS, UART_LCR_DLAB_BIT);

            write_u8(
                BASE_ADDR + UART_IIR_FCR_OFS,
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
            write_u8(BASE_ADDR + UART_MCR_OFS, 0x20);
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
    /// sure to call [ApbUartHal::init] prior to this call, otherwise the UART
    /// won't behave properly.
    pub const unsafe fn instance() -> Self {
        Self {}
    }

    #[inline]
    pub fn write_str(&mut self, s: &str) {
        // SAFETY: UART impl is currently infallible
        unsafe { self.write(s.as_bytes()).unwrap_unchecked() };
    }

    /// Writes a byte into UART
    ///
    /// Blocks until the transmit FIFO is empty before transmitting.
    #[inline]
    fn putc(&mut self, c: u8) {
        while !self.is_transmit_empty() {}
        // Safety: UART_THR is 4-byte aligned
        unsafe { write_u8(BASE_ADDR + UART_RBR_THR_DLL_OFS, c) };
    }

    #[inline]
    pub fn getc(&mut self) -> u8 {
        // Wait for data to become ready
        while unsafe { read_u8(BASE_ADDR + UART_LSR_OFS) } & UART_LSR_RX_FIFO_VALID_BIT == 0 {}

        // SAFETY: UART0_ADDR is 4-byte aligned
        unsafe { read_u8(BASE_ADDR) }
    }

    /// Assert bit to cause hardware to raise an interrupt on specified UART
    /// interrupt.
    #[inline]
    pub fn listen(&mut self, int: UartInterrupt) {
        unsafe {
            // Save LCR for restoration
            let p_lcr = read_u8(BASE_ADDR + UART_LCR_OFS);

            // Deassert `LCR[7]` => IER_DLM is IER
            let lcr = p_lcr & (0b1 << 7);
            write_u8(BASE_ADDR + UART_LCR_OFS, lcr);

            // Set IER
            write_u8(BASE_ADDR + UART_IER_DLM_OFS, int as u8);

            // Restore `LCR`
            write_u8(BASE_ADDR + UART_LCR_OFS, p_lcr);
        }
    }

    #[inline]
    fn is_transmit_empty(&self) -> bool {
        // Safety: UART_LINE_STATUS is 4-byte aligned
        unsafe { (read_u8(BASE_ADDR + UART_LSR_OFS) & 0x20) != 0 }
    }
}

#[derive(Debug)]
pub struct UartError;

impl embedded_io::Error for UartError {
    fn kind(&self) -> embedded_io::ErrorKind {
        // Error kinds not implemented for BSP right now
        embedded_io::ErrorKind::Other
    }
}

impl<const BASE_ADDR: usize> embedded_io::ErrorType for ApbUartHal<BASE_ADDR> {
    type Error = UartError;
}

impl<const BASE_ADDR: usize> embedded_io::Write for ApbUartHal<BASE_ADDR> {
    #[inline]
    fn write(&mut self, buf: &[u8]) -> Result<usize, Self::Error> {
        for b in buf {
            self.putc(*b);
        }
        Ok(buf.len())
    }

    #[inline]
    fn flush(&mut self) -> Result<(), Self::Error> {
        // Wait for hardware to report completion
        while !self.is_transmit_empty() {}
        Ok(())
    }
}
