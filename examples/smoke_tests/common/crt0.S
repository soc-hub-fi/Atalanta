/*Change it if necessary...*/
/*Make sure it's 16-bytes aligned*/
#define VTABLE_ADDR 0x0
#define SHARED_VAR_ADDR 0x2F00
#define GPIO_OUTPUT_ADDR 0x00030008
#define MTIME_CTRL_ADDR  0x00030210

/*For risc-v's LOAD IMMEDIATE instruction*/
#define SHARED_VAR_ADDR_IMM (SHARED_VAR_ADDR >> 4)



  .section .text

reset_handler:
  la x2, stack
  addi gp, x0, SHARED_VAR_ADDR_IMM   
  slli gp, gp, 4    // Reconstruct the address of shared_var and assign it to global pointer 
  sw x0, 0(gp)      // Initialize the shared variable 
  j main


  
  .global changeStack
changeStack:
  mv sp, a2
  jr a1

  .section .vectors, "ax"
  .option norvc;
  .org VTABLE_ADDR
  jal x0, reset_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler  // CLINT Reserved: Software exception
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  .4byte  mtimer_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  .4byte irq_handler_29
  .4byte irq_handler_30
  jal x0, default_handler    // CLINT RESERVED: NMI 
  //.4byte irq_handler_30
  //.4byte irq_handler_31

  //// reset vector
  .org 0x80
  jal x0, reset_handler

  .org 0x84
loop:
  j loop


default_handler:
  mret


  .org 0xA0
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

    addi gp, x0, SHARED_VAR_ADDR_IMM   
    slli gp, gp, 4
    
    lw t0, 0(gp)     // Test the value of shared variable 
    beq t0, zero, -4    

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

    //csrsi mcountinhibit, 1              // Mitigates funny time-reversals        

  //---------------------------------------------> pause mcycle perf monitor 

    //csrr  t0, mcycleh 
    //sw    t0, 12(gp)                     // Store high-order 4-bytes of mcycle into the global section
    //csrr  t0, mcycle 
    //sw    t0, 16(gp)                     // Store low-order 4-bytes of mcycle into the global section

    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */


    li t0, 0x0F1
    sw t0, 0(gp)                         // Release the resource... main can resume
    

    csrci mstatus, 8 /* disable global interrupts*/


    csrci mcountinhibit, 1              // Resume mcycle perf monitor  
//------------------------------------> resume mcycle perf monitor 
    
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


.org 0x41C
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

