//! Prints all CSRs added by Atalanta and the most interesting base ISA
//! registers.
#![no_main]
#![no_std]

use bsp::{
    // Import all registers from `bsp::register::*`
    register::*,
    riscv::asm::wfi,
    rt::entry,
    uart::*,
    CPU_FREQ,
};
use hello_rt::{print_example_name, UART_BAUD};

macro_rules! print_struct_csr {
    ($csr:path) => {
        sprintln!("{}: {:#x}", stringify!($csr), $csr::read().bits());
    };
}

macro_rules! print_csr {
    ($csr:path) => {
        sprintln!("{}: {:#x}", stringify!($csr), $csr::read());
    };
}

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);

    print_example_name!();

    // Print all registers added by Atalanta BSP and the most interesting base ISA
    // registers.

    print_csr!(mconfigptr);
    print_struct_csr!(mtvec);
    print_struct_csr!(mtvt);
    print_struct_csr!(mintstatus);
    print_struct_csr!(mintthresh);
    print_csr!(mclicbase);
    assert_eq!(mclicbase::read(), bsp::mmap::CLIC_BASE_ADDR);
    print_csr!(cpuctrlsts);
    print_csr!(secureseed);

    #[cfg(feature = "rtl-tb")]
    bsp::tb::rtl_tb_signal_ok();

    loop {
        wfi();
    }
}
