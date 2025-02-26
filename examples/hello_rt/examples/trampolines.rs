//! Example to generate the assembly code for all available interrupt handling
//! strategies for comparison.
#![no_main]
#![no_std]
#![allow(non_snake_case)]

use core::arch::global_asm;

use bsp::{
    clic::{Clic, Polarity, Trig},
    interrupt, mask_u32,
    mmap::CLIC_BASE_ADDR,
    mtimer::{self, MTimer},
    nested_interrupt,
    riscv::{self, asm::wfi},
    rt::entry,
    uart::*,
    unmask_u32, Interrupt, CPU_FREQ,
};
use hello_rt::{print_example_name, tear_irq, UART_BAUD};

fn enable_pcs(irq: Interrupt) {
    const PCS_BIT_IDX: u32 = 12;
    mask_u32(
        CLIC_BASE_ADDR + 0x1000 + 0x04 * irq as usize,
        0b1 << PCS_BIT_IDX,
    );
}

fn disable_pcs(irq: Interrupt) {
    const PCS_BIT_IDX: u32 = 12;
    unmask_u32(
        CLIC_BASE_ADDR + 0x1000 + 0x04 * irq as usize,
        0b1 << PCS_BIT_IDX,
    );
}

const TIMEOUT: mtimer::Duration = mtimer::Duration::micros_at_least(5);

#[entry]
fn main() -> ! {
    let _serial = ApbUart::init(CPU_FREQ, UART_BAUD);
    print_example_name!();

    // Set level bits to 8
    Clic::smclicconfig().set_mnlbits(8);

    // Emulate software interrupts with DMA interrupts
    setup_irq(Interrupt::Dma0, 0x1);
    setup_irq(Interrupt::Dma1, 0x2);
    setup_irq(Interrupt::Dma2, 0x3);
    setup_irq(Interrupt::Dma3, 0x4);
    setup_irq(Interrupt::Dma4, 0x5);
    setup_irq(Interrupt::Dma5, 0x6);
    setup_irq(Interrupt::MachineTimer, u8::MAX);

    enable_pcs(Interrupt::Dma2);
    enable_pcs(Interrupt::Dma4);
    enable_pcs(Interrupt::Dma5);

    // Use mtimer for timeout
    let mut mtimer = MTimer::instance().into_oneshot();

    unsafe { riscv::interrupt::enable() };
    mtimer.start(TIMEOUT);

    unsafe {
        Clic::ip(Interrupt::Dma0).pend();
        Clic::ip(Interrupt::Dma1).pend();
        Clic::ip(Interrupt::Dma2).pend();
        Clic::ip(Interrupt::Dma3).pend();
        Clic::ip(Interrupt::Dma4).pend();
        Clic::ip(Interrupt::Dma5).pend();
    }

    loop {
        wfi();
    }
}

#[no_mangle]
static mut CNT0: usize = 0;
#[no_mangle]
static mut CNT1: usize = 0;
#[no_mangle]
static mut CNT2: usize = 0;
#[no_mangle]
static mut CNT3: usize = 0;
#[no_mangle]
static mut CNT4: usize = 0;
#[no_mangle]
static mut CNT5: usize = 0;

// Non-nested non-PCS interrupt
#[interrupt]
fn Dma0() {
    unsafe { CNT0 += 1 };
}

// Nested non-PCS interrupt
#[nested_interrupt]
fn Dma1() {
    unsafe { CNT1 += 1 };
}

// Nested PCS interrupt
#[nested_interrupt(pcs)]
fn Dma2() {
    unsafe { CNT2 += 1 };
}

// Nested non-PCS with separately generated entry point
bsp::generate_nested_trap_entry!(Dma3);
#[no_mangle]
fn Dma3() {
    unsafe { CNT3 += 1 };
}

// Nested PCS with separately generated entry point
bsp::generate_pcs_trap_entry!(Dma4);
#[no_mangle]
fn Dma4() {
    unsafe { CNT4 += 1 };
}

// Nested PCS interrupt in assembly (Dma5)
global_asm!(
    r#"
.section .trap, "ax"
.align 4
.global _start_Dma5_trap
_start_Dma5_trap:
    #----- Interrupts disabled on entry ---#
    csrsi mstatus, 8    // enable interrupts
    #----- Interrupts enabled -------------#
    // Save context
    addi    sp,sp,-8
    sw      a0,4(sp)
    sw      a1,0(sp)

    // Increment CNT
    lla     a0, {CNT}
    lw      a1, 0(a0)
    addi    a1,a1,1
    sw      a1, 0(a0)

    // Restore context
    lw      a0,4(sp)
    lw      a1,0(sp)
    addi    sp,sp,8
    csrci mstatus, 8    // disable interrupts
    #----- Interrupts disabled  ---------#
    mret
"#, CNT = sym CNT5
);

#[inline]
fn setup_irq(irq: Interrupt, level: u8) {
    Clic::attr(irq).set_trig(Trig::Edge);
    Clic::attr(irq).set_polarity(Polarity::Pos);
    Clic::attr(irq).set_shv(true);
    Clic::ctl(irq).set_level(level);
    unsafe { Clic::ie(irq).enable() };
}

/// Timeout interrupt (per test-run)
#[interrupt]
unsafe fn MachineTimer() {
    unsafe {
        #![allow(static_mut_refs)]

        // Check for interrupts starting from most stable to least stable
        assert_eq!(CNT0, 1);
        assert_eq!(CNT1, 1);
        assert_eq!(CNT2, 1);
        assert_eq!(CNT3, 1);
        assert_eq!(CNT4, 1);
        assert_eq!(CNT5, 1);

        // Test tear down
        tear_irq(Interrupt::Dma0);
        tear_irq(Interrupt::Dma1);
        tear_irq(Interrupt::Dma2);
        tear_irq(Interrupt::Dma3);
        tear_irq(Interrupt::Dma4);
        tear_irq(Interrupt::Dma5);
        tear_irq(Interrupt::MachineTimer);
        disable_pcs(Interrupt::Dma2);
        disable_pcs(Interrupt::Dma4);
        disable_pcs(Interrupt::Dma5);

        bsp::tb::signal_pass(Some(&mut ApbUart::instance()));
    }
}
