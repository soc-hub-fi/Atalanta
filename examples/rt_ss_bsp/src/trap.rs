use core::arch::{asm, global_asm};
use riscv::register::mtvec;

#[cfg(feature = "rt")]
#[export_name = "_setup_interrupts"]
fn setup_interrupt_vector() {
    // Set the trap vector
    unsafe {
        extern "C" {
            fn _vector_table();
        }

        // Set all the trap vectors for good measure
        let bits = _vector_table as usize;
        mtvec::write(bits, mtvec::TrapMode::Clic);
        // 0x307 = mtvt
        asm!("csrw 0x307, {0}", in(reg) bits | 0x3);

        // 0x347 = mintthresh
        asm!("csrw 0x347, 0x00");
    }
}

// The vector table
//
// N.b. vectors length must be exactly 0x80
#[cfg(feature = "rt")]
global_asm!(
    "
.section .vectors, \"ax\"
    .global _vector_table
    .type _vector_table, @function

    .option push
    // RISC-V specifies that _vector_table must be 4-byte aligned but our CLIC
    // requires the more strict 64-byte alignment
    .p2align 6
    .option norelax
    .option norvc

    _vector_table:
        // Use [0] as exception entry point
        j _start_trap
        // [1..=16] are standard
        .word _start_SupervisorSoft_trap    // 1
        .word _start_DefaultHandler_trap
        .word _start_MachineSoft_trap       // 3
        .word _start_DefaultHandler_trap
        .word _start_SupervisorTimer_trap   // 5
        .word _start_DefaultHandler_trap
        .word _start_MachineTimer_trap      // 7
        .word _start_DefaultHandler_trap
        .word _start_SupervisorExternal_trap // 9
        .word _start_DefaultHandler_trap
        .word _start_MachineExternal_trap   // 11
        .rept 5
        .word _start_DefaultHandler_trap    // 12..=16
        .endr
        .word _start_Uart_trap              // 17
        .word _start_Gpio_trap              // 18
        .word _start_SpiRxTxIrq_trap        // 19
        .word _start_SpiEotIrq_trap         // 20
        .word _start_Timer0Ovf_trap         // 21
        .word _start_Timer0Cmp_trap         // 22
        .word _start_Timer1Ovf_trap         // 23
        .word _start_Timer1Cmp_trap         // 24
        .word _start_Timer2Ovf_trap         // 25
        .word _start_Timer2Cmp_trap         // 26
        .word _start_Timer3Ovf_trap         // 27
        .word _start_Timer3Cmp_trap         // 28

        // Pad with `DefaultHandler`
        .rept 2
        .word _start_DefaultHandler_trap    // 29..=30
        .endr

        .word _start_Nmi_trap   // 31
        .word _start_Dma0_trap  // 32
        .word _start_Dma1_trap  // 33
        .word _start_Dma2_trap  // 34
        .word _start_Dma3_trap  // 35
        .word _start_Dma4_trap  // 36
        .word _start_Dma5_trap  // 37
        .word _start_Dma6_trap  // 38
        .word _start_Dma7_trap  // 39
        .word _start_Dma8_trap  // 40
        .word _start_Dma9_trap  // 41
        .word _start_Dma10_trap // 42
        .word _start_Dma11_trap // 43
        .word _start_Dma12_trap // 44
        .word _start_Dma13_trap // 45
        .word _start_Dma14_trap // 46
        .word _start_Dma15_trap // 47

        // Fill the rest with `DefaultHandler`
        .rept 16
        .word _start_DefaultHandler_trap // 48..64
        .endr

        // TODO: add remaining missing interrupts

    .option pop",
);
