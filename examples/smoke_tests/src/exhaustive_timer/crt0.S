
/*Change it if necessary...*/
/*Make sure it's 16-bytes aligned*/
#define VTABLE_ADDR 0x0
#define MTIME_CTRL_ADDR  0x00030210
#define MTIMECMP_LOW_ADDR 0x00030208

#define NUM_INTERRUPTS 66
//#define HARDWARE_STACKING  

.extern pend_int
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
  .4byte irq_handler_0
  .4byte default_handler
  .4byte default_handler  // CLINT Reserved: Software exception
  .4byte default_handler
  .4byte default_handler
  .4byte default_handler
  .4byte mtimer_handler
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0    // line 16
  .4byte uart_handler_1
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0  
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0 
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0 
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0    
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0    
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0    
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .4byte irq_handler_0
  .org 0x100
  jal x0, reset_handler //// reset vector


  .org 0x180 //0x84
loop:
  j loop

default_handler:
  mret


  .org 0x1F0 //0xA0
.global irq_handler_0
.func
irq_handler_0:
    #ifndef HARDWARE_STACKING
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mepc
    csrr t1, mcause
    sw t0, 28(sp)
    sw t1, 32(sp)
    #endif
    
    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */
    addi gp, x0, 0x500   
    slli gp, gp, 4
    lw t0, 0(gp) 
    addi t0, t0, 0x1      // increment the counter(shared varibale)  
    sw t0, 0(gp)
    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t1
    csrw mepc, t0
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





.org 0x41C
.global mtimer_handler
.func
mtimer_handler:
    //disable timer
   #ifndef HARDWARE_STACKING
    addi sp, sp, -(4 * 9)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw a0, 8(sp)
    sw a1, 12(sp)
    sw a2, 16(sp)
    sw a3, 20(sp)
    sw t1, 24(sp)
    csrr t0, mepc
    csrr t1, mcause
    sw t0, 28(sp)
    sw t1, 32(sp)
    #endif


    csrsi mstatus, 8 /* re-enable global interrupts enable recursion */

    la a2, 0x5E00
    lw a3, 0(a2)
    addi a3, a3, -1
    sw a3, 0(a2)
    beq a3, x0, quit    // exit when dec_count reaches 0

    #Disable timer [bit 0] & set prescaler to 00F [bits 20:8]
    li t0, 0x00F00              
    la t1, MTIME_CTRL_ADDR       
    sw t0, 0(t1) 
    nop                 //stalling is needed here (ibex issue)
    beq a3, x0, quit    // exit when dec_count reaches 0


    la t1, MTIMECMP_LOW_ADDR     
    lw t0, 0(t1)
    addi t0,t0, 0x20           
    sw t0, 0(t1)               #Update mtimecmp to for different time intervals   

    #Enable timer [bit 0] & set prescaler to 00F [bits 20:8]
    li t0, 0x00F01              
    la t1, MTIME_CTRL_ADDR       
    sw t0, 0(t1) 

    addi gp, x0, 0x5F0   
    slli gp, gp, 4
    lw a0, 0(gp)
    addi a0, a0, 1         
    sw a0, 0(gp)
    jal pend_int        // (pend the next interrupt line) 

    nop 
    nop 
    nop 

    quit:
    csrci mstatus, 8 /* disable global interrupts*/

    lw t0, 28(sp)
    lw t1, 32(sp)
    csrw mcause, t1
    csrw mepc, t0
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
