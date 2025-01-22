//! Register maps for [PULP APB UART](https://github.com/pulp-platform/apb_uart/) (v0.2.1)
//!
//! Some implementations of APB UART space registers with one byte offset but
//! Atalanta uses 4 bytes as tends to be conventional.
pub const UART_BASE: usize = 0x3_0100;

/// Receiver Buffer Register (RBR) / Transmitter Holding Register (THR) /
/// Divisor Latch LSB (DLL)
///
/// - `LCR[7] == 0`: RBR and THR are accessible
/// - `LCR[7] == 1`: DLL is accessible
///
/// ## Receiver Buffer Register (read-only)
///
/// Returns the next character buffered on UART and clears the register.
///
/// ## Transmitter Holding Register (write-only)
///
/// Sets the byte to be transmitted over UART.
///
/// ## Divisor latch LSB (read-write)
///
/// Reads or writes the 8 LSBs of the divisor that --- together with clock
/// frequency --- determines resultant BAUD rate.
pub const UART_RBR_THR_DLL: usize = UART_BASE + 0;
pub const UART_DLAB_LSB: usize = UART_RBR_THR_DLL;

/// Interrupt Enable Register (IER) / Divisor Latch MSB (DLM)
///
/// - `LCR[7] == 0`: IER is accessible
/// - `LCR[7] == 1`: DLM is accessible
///
/// ## Interrupt Enable Register (read-write, `[0:2]`)
///
/// - `[0]`: Interrupt is raised when...
///     - (fifo disabled) received data is available
///     - (fifo enabled) trigger level has been reached (sa. [UART_IIR_FCR])
///     - character timeout has been reached
/// - `[1]`: Interrupt is raised when [UART_RBR_THR_DLL] is empty
/// - `[2]`: Interrupt is raised on Overrun error, parity error, framing error
///   or break interrupt
///
/// ## Divisor latch LSB (read-write)
///
/// Reads or writes the 8 MSBs of the divisor that --- together with clock
/// frequency --- determines resultant BAUD rate.
pub const UART_IER_DLM: usize = UART_BASE + 4;
pub const UART_DLAB_MSB: usize = UART_IER_DLM;

/// Interrupt Identification Register (IIR) / FIFO Control Register (FCR)
///
/// ## Interrupt Identification Register (read-only)
///
/// ## FIFO Control Register (write-only)
///
/// - `[1]`: Clear the RX FIFO
/// - `[2]`: Clear the TX FIFO
/// - `[6:7]`: Set the trigger level
///     - `0b00`: trigger level is high when there is 1 element in the fifo
///     - `0b01`: trigger level is high when there are 4 elements in the fifo
///     - `0b10`: trigger level is high when there are 8 elements in the fifo
///     - `0b11`: trigger level is high when there are 14 elements in the fifo
pub const UART_IIR_FCR: usize = UART_BASE + 8;

/// Line Control Register
///
/// LCR configures the main operation of the uart. It configures the width of
/// the received data, stop bit, parity, and DLAB bit.
///
/// - `[0:1]`: data configuration bits
///     - `0b00`: data is configured to be 5 bits
///     - `0b01`: data is configured to be 6 bits
///     - `0b10`: data is configured to be 7 bits
///     - `0b11`: data is configured to be 8 bits
/// - `[2]`: stop bit configuration
///     - `0b0`: 1 stop bit
///     - `0b1`: 1.5 stop bits for 5 bits data word OR 2 stop bits 6, 7 or 8
///       bits data word
/// - `[3]`: parity enable bit
/// - `[7]`: divisor latch access bit (DLAB)
///     - `0b0`: RBR, THR and IER accessible
///     - `0b1`: DLL and DLM accessible
pub const UART_LCR: usize = UART_BASE + 12;

/// Modem Control
pub const UART_MCR: usize = UART_BASE + 16;

/// Line Status Register
///
/// - `[0]`: RX FIFO data valid
/// - `[1]`: *not used*
/// - `[2]`: parity error from the RX FIFO
/// - `[3]`: *not used*
/// - `[4]`: *not used*
/// - `[5]`: the TX FIFO is empty
/// - `[6]`: shift register and TX FIFO are empty
pub const UART_LSR: usize = UART_BASE + 20;
