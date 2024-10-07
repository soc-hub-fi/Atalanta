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
        j _start_trap                         // Interrupt 0 is used for exceptions
        .word _start_SupervisorSoft_trap
        .word _start_DefaultHandler_trap      // Interrupt 2 is reserved
        .word _start_MachineSoft_trap
        .word _start_DefaultHandler_trap      // Interrupt 4 is reserved
        .word _start_SupervisorTimer_trap
        .word _start_DefaultHandler_trap      // Interrupt 6 is reserved
        .word _start_MachineTimer_trap
        .word _start_DefaultHandler_trap      // Interrupt 8 is reserved
        .word _start_SupervisorExternal_trap
        .word _start_DefaultHandler_trap      // Interrupt 10 is reserved
        .word _start_MachineExternal_trap
        .rept 4
        .word _start_DefaultHandler_trap // 12..15
        .endr
        .word _start_Sixteen_trap             // Placeholder
        .word _start_Seventeen_trap           // Placeholder
        // Fill rest with the address of _start_DefaultHandler_trap. These get routed to `DefaultHandler`.
        .rept 14
        .word _start_DefaultHandler_trap // 18..31
        .endr

        // TODO: add remaining missing interrupts

    .option pop",
);
