#![no_std]
#![no_main]

pub mod clic;

pub const UART_BAUD: u32 = if cfg!(feature = "rtl-tb") {
    3_000_000
} else {
    9600
};
