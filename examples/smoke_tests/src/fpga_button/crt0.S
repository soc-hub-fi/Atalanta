/*Change it if necessary...*/
/*Make sure it's 16-bytes aligned*/
#define VTABLE_ADDR 0x0
#define SHARED_VAR_ADDR 0x5F00

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

change_stack:
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
  .4byte default_handler //mtime_handler 
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler    // line 16
  .4byte default_handler     //uart_handler_1
  .org 0x100
  jal x0, reset_handler //// reset vector


  .org 0x180 //0x84
loop:
  j loop

default_handler:
  mret


