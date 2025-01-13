/*
  UART test code based on CVA6 reference
*/

#include <stdint.h>
#include "../include/uart_interrupt.h"
#include "../include/csr_utils.h"



#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200
#define TIMESTAMPS_BASE    0x00002F00
#define MTIME_LOW_ADDR     (TIMER_BASE_ADDR +  0)
#define MTIME_HIGH_ADDR    (TIMER_BASE_ADDR +  4)
#define MTIMECMP_LOW_ADDR  (TIMER_BASE_ADDR +  8)
#define MTIMECMP_HIGH_ADDR (TIMER_BASE_ADDR + 12)
#define MTIME_CTRL_ADDR    (TIMER_BASE_ADDR + 16)

void stamp_print(uint32_t addr_begin, uint16_t num_stamps){
    uint32_t *p = (uint32_t *)addr_begin;
    uint32_t reg = 0;
    uint32_t count = 0;

    while(p < addr_begin + num_stamps * sizeof(uint64_t)){
        reg = *p;

        print_uart("[UART] Timestamp # ");
        print_uart_int(++count);
        print_uart(" ==============> ");
        print_uart_int(reg);

        reg = *(++p);
        print_uart_int(reg);
        print_uart(" Clock Cycles");
        print_uart("\n");

        p++;
    }
}

int main(){

  init_uart(100000000/2, 3000000/2); // 50 MHz for simulation, 40 MHz for FPGA

  print_uart("[UART] Hello from mock UART!\n");
  print_uart("[UART] UART_TEST [PASSED]\n");

  *((volatile uint32_t *)(TIMESTAMPS_BASE)) = 0;
  csr_write(CSR_MCYCLE, 0);
  csr_write(CSR_MCYCLEH, 0);

  *(uint32_t*)(MTIMECMP_LOW_ADDR) = 7; 

  /*Start perf counter*/
  asm("li gp, 0x2f00");
  //asm("addi gp, zero, 0x2f00");
  //csr_read_clear(CSR_MCOUNTINHIBIT, 0x1);
  asm("csrrc a5, mcountinhibit, a5");
//----------------------------------------------------------------> start mcycle perf monitor

  volatile uint32_t dummy_load = *(uint32_t*)(MTIMECMP_LOW_ADDR);
  uint32_t reg = 15 / dummy_load;

//----------------------------------------------------------------> return from interrupt handler
  /*Disable mcycle perf monitor (enabled by default at bootup/reset)*/
  //csr_read_set(CSR_MCOUNTINHIBIT, 0x1);
  asm("csrrs a5, mcountinhibit, a5");

   /*
       store timestamps in big-endian
   */
  asm("csrr  t0, mcycleh");
  asm("sw    t0, 0(gp)");
  asm("csrr  t0, mcycle");
  asm("sw    t0, 4(gp)");
  asm("nop");


  *((volatile uint32_t *)(TIMESTAMPS_BASE+4)) = *((volatile uint32_t *)(TIMESTAMPS_BASE+4)) - 0xD;
  stamp_print(TIMESTAMPS_BASE, 1);

  *(uint32_t*)(OUTPUT_REG_ADDR) = 1;
  while (1)
    ;
  
}
