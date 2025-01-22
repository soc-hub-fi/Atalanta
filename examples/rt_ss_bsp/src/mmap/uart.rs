pub const UART_BASE: usize = 0x30100;

pub const UART_RBR_THR_DLL: usize = UART_BASE + 0;
pub const UART_IER_DLM: usize = UART_BASE + 4;
pub const UART_IIR_FCR: usize = UART_BASE + 8;
pub const UART_LCR: usize = UART_BASE + 12;

/// Modem Control
pub const UART_MCR: usize = UART_BASE + 16;
pub const UART_LSR: usize = UART_BASE + 20;
pub const UART_DLAB_LSB: usize = UART_BASE + 0;
pub const UART_DLAB_MSB: usize = UART_BASE + 4;
