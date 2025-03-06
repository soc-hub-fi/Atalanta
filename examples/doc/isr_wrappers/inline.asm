.section .trap, "ax"
.align 4
.global _start_inline_trap
_start_inline_trap:
    #----- Interrupts disabled on entry ---#
    csrsi mstatus, 8    // enable interrupts
    #----- Interrupts enabled -------------#

    // Increment CNT
    auipc   a0, 0x4
    addi    a0, a0, 938 # 5654 <CNT>
    lw      a1, 0(a0)
    addi    a1, a1, 1
    sw      a1, 0(a0)

    csrci mstatus, 8    // disable interrupts
    #----- Interrupts disabled  ---------#
    mret
