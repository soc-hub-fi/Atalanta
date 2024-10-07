pub const UART_BASE: usize = 0x30100;

pub const UART_THR: usize = UART_BASE + 0;
pub const UART_INTERRUPT_ENABLE: usize = UART_BASE + 4;
pub const UART_FIFO_CONTROL: usize = UART_BASE + 8;
pub const UART_LINE_CONTROL: usize = UART_BASE + 12;
pub const UART_MODEM_CONTROL: usize = UART_BASE + 16;
pub const UART_LINE_STATUS: usize = UART_BASE + 20;
pub const UART_DLAB_LSB: usize = UART_BASE + 0;
pub const UART_DLAB_MSB: usize = UART_BASE + 4;
