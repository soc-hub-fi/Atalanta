/*Change it if necessary...*/
/*Make sure it's 16-bytes aligned*/
.equ    VTABLE_ADDR,      0x0


.equ    SHARED_VAR_ADDR,  0x00002F00
.equ    GPIO_OUTPUT_ADDR, 0x00030008
.equ    MTIME_CTRL_ADDR,  0x00030210
.equ


  .section .text

reset_handler:
  la x2, stack
  la gp, SHARED_VAR_ADDR
  sw x0, 0(gp)      // Initialize the shared variable
  j main



  .global change_stack
change_stack:
  mv sp, a2
  jr a1

  .section .vectors, "ax"
  .option norvc;
  .org VTABLE_ADDR
  jal x0, reset_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler   // CLINT Reserved: Software interrupt
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  .4byte  mtimer_handler
  jal x0, default_handler
  .4byte  irq_handler_9
  .4byte  irq_handler_10
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  .4byte  irq_handler_14
  .4byte  irq_handler_15
  .4byte  irq_handler_16
  .4byte  irq_handler_17
  .4byte  irq_handler_18
  .4byte  irq_handler_19
  .4byte  irq_handler_20
  .4byte  irq_handler_21
  .4byte  irq_handler_22
  .4byte  irq_handler_23
  .4byte  irq_handler_24
  .4byte  irq_handler_25
  .4byte  irq_handler_26
  .4byte  irq_handler_27
  .4byte  irq_handler_28
  .4byte  irq_handler_29
  .4byte  irq_handler_30
  jal x0, default_handler    // CLINT RESERVED: NMI

  //// reset vector
  .org 0x80
  jal x0, reset_handler

  .org 0x84
loop:
  j loop


default_handler:
  mret



.align
.global mtimer_handler
.func
mtimer_handler:
    //disable timer
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 28(sp)
    sw t1, 32(sp)


    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */

    la t0, MTIME_CTRL_ADDR
    sw x0, 0(t0)
    la t0, GPIO_OUTPUT_ADDR
    addi t1, t1, 0xFF
    sw t1, 0(t0)

    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a2, 16(sp)
    lw a3, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc


.align
.global irq_handler_27
.func
irq_handler_29:
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 28(sp)
    sw t1, 32(sp)

    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */

    li  a0, 28
    jal pend_int
    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a2, 16(sp)
    lw a3, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc


.align
.global irq_handler_28
.func
irq_handler_29:
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 28(sp)
    sw t1, 32(sp)

    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */


    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a2, 16(sp)
    lw a3, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc


.align
.global irq_handler_29
.func
irq_handler_29:
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 28(sp)
    sw t1, 32(sp)

    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */


    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a2, 16(sp)
    lw a3, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc


.align
.global irq_handler_30
.func
irq_handler_30:
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 28(sp)
    sw t1, 32(sp)


    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */



    csrci mstatus, 8 /* disable global interrupts*/
    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a2, 16(sp)
    lw a3, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc
