use crate::{mmap::*, read_u8, write_u8};

pub fn init_uart(freq: u32, baud: u32) {
    let divisor: u32 = freq / (baud << 4);

    // Safety: unaligned writes may fail on rt-ss
    // TODO: this code should be verified for expected results on a simulator
    unsafe {
        // Disable all interrupts
        write_u8(UART_INTERRUPT_ENABLE, 0x00);
        // Enable DLAB (set baud rate divisor)
        write_u8(UART_LINE_CONTROL, 0x80);
        // Divisor (lo byte)
        write_u8(UART_DLAB_LSB, divisor as u8);
        // Divisor (hi byte)
        write_u8(UART_DLAB_MSB, (divisor >> 8) as u8);
        // 8 bits, no parity, one stop bit
        write_u8(UART_LINE_CONTROL, 0x03);
        // Enable FIFO, clear them, with 14-byte threshold
        write_u8(UART_FIFO_CONTROL, 0xC7);
        // Autoflow mode
        write_u8(UART_MODEM_CONTROL, 0x20);
    }
}

pub fn uart_write(s: &str) {
    for c in s.bytes() {
        putc(c as u32);
    }
    // The UART device seems to require the nul-byte at the end of the transmission
    // for some reason ':D
    putc(0);
}

pub fn is_transmit_empty() -> bool {
    // Safety: unaligned writes may fail on rt-ss
    // TODO: this code should be verified for expected results on a simulator
    unsafe { (read_u8(UART_LINE_STATUS) & 0x20) != 0 }
}

fn putc(c: u32) {
    while !is_transmit_empty() {}
    unsafe { core::ptr::write_volatile(UART_THR as *mut _, c) };
}
