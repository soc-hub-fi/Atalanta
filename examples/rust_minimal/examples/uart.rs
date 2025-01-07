#![no_main]
#![no_std]

// Make sure to link in runtime necessities
use rust_minimal::{read_u8, write_u8, UART_BAUD};

const UART_BASE: usize = 0x30100;

const UART_THR: usize = UART_BASE + 0;
const UART_INTERRUPT_ENABLE: usize = UART_BASE + 4;
const UART_FIFO_CONTROL: usize = UART_BASE + 8;
const UART_LINE_CONTROL: usize = UART_BASE + 12;
const UART_MODEM_CONTROL: usize = UART_BASE + 16;
const UART_LINE_STATUS: usize = UART_BASE + 20;
const UART_DLAB_LSB: usize = UART_BASE + 0;
const UART_DLAB_MSB: usize = UART_BASE + 4;

fn init_uart(freq: u32, baud: u32) {
    const PERIPH_CLK_DIV: u32 = 2;
    let divisor: u32 = freq / PERIPH_CLK_DIV / (baud << 4);

    // Safety: all UART registers are 4-byte aligned which makes the below writes
    // always valid
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

fn uart_write(s: &str) {
    for c in s.bytes() {
        putc(c);
    }
}

fn is_transmit_empty() -> bool {
    // Safety: UART_LINE_STATUS is 4-byte aligned
    (read_u8(UART_LINE_STATUS) & 0x20) != 0
}

fn putc(c: u8) {
    while !is_transmit_empty() {}
    // Safety: UART_THR is 4-byte aligned
    write_u8(UART_THR, c);
}

/// Example entry point
#[no_mangle]
pub unsafe extern "C" fn entry() -> ! {
    init_uart(rust_minimal::CPU_FREQ, UART_BAUD);
    uart_write("Hello world!");
    loop {}
}
