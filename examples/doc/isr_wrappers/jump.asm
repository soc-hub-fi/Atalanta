.section .trap, "ax"
.align 4
.global _start_jump_trap
_start_jump_trap:
    #----- Interrupts disabled on entry ---#
    csrsi mstatus, 8    // enable interrupts
    #----- Interrupts enabled -------------#

    // Jump
    auipc   a0,0x0
    addi    a0,a0,492 # 1470 <Trap>
    jalr    a0

    // Epilogue
    csrci mstatus, 8    // disable interrupts
    #----- Interrupts disabled  ---------#
    mret

Trap:
    // Increment CNT
    lui a0, 0x5
    lw  a1, 1616(a0) # 5650 <CNT>
    addi a1, a1, 1
    sw a1, 1616(a0)
    ret
