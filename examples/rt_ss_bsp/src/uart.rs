use crate::mmap::*;
use crate::{read_u8, write_u8};

#[cfg(any(all(feature = "fpga", feature = "rt"), feature = "panic"))]
pub(crate) static mut UART_IS_INIT: bool = false;

pub fn init_uart(freq: u32, baud: u32) {
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
}

pub fn uart_write(s: &str) {
    for c in s.bytes() {
        putc(c);
    }
}

pub fn is_transmit_empty() -> bool {
    // Safety: UART_LINE_STATUS is 4-byte aligned
    unsafe { (read_u8(UART_LSR) & 0x20) != 0 }
}

pub fn putc(c: u8) {
    while !is_transmit_empty() {}
    // Safety: UART_THR is 4-byte aligned
    unsafe { write_u8(UART_RBR_THR_DLL, c) };
}
