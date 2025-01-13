#define VTABLE_ADDR 0x0
#define NUM_INTERRUPTS 66
//#define HARDWARE_STACKING  

.extern uart_handler

  .section .text

reset_handler:
  la x2, stack 
  la ra, exit_status
  j main

  .global exit_status
exit_status:
  li t0, 0x00000380
  li t1, 0x80000000
  or a0, a0, t1
  sw a0, 0(t0)
  wfi

  .global changeStack
changeStack:
  mv sp, a2
  jr a1

  .section .vectors, "ax"
  .option norvc;
  .org VTABLE_ADDR
  jal x0, reset_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler  // CLINT Reserved: Software exception
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler    // line 16
  .4byte uart_handler_1
  .org 0x100
  jal x0, reset_handler //// reset vector


  .org 0x180 //0x84
loop:
  j loop

default_handler:
  mret

    .org 0x2F0 //0xA0
.global uart_handler_1
.func
uart_handler_1:
    #ifndef HARDWARE_STACKING
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a4, 16(sp)
    sw a5, 20(sp)
    sw t1, 24(sp)
    csrr t0, mepc
    csrr t1, mcause
    sw t0, 28(sp)
    sw t1, 32(sp)
    #endif
    
    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */
     
    
    call uart_handler
  

    csrci mstatus, 8 /* disable global interrupts*/

    // I expanded stack size to prevent stack overflow due multiple nesting 

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t1
    csrw mepc, t0
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw a0, 8(sp)
    lw a1, 12(sp)
    lw a4, 16(sp)
    lw a5, 20(sp)
    lw t1, 24(sp)
    addi sp, sp, (4 * 9)
    mret
.endfunc


