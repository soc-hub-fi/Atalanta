#include <stdint.h>
#include "include/clic.h"
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

#define MTIME_LOW_ADDR     (TIMER_BASE_ADDR +  0)
#define MTIME_HIGH_ADDR    (TIMER_BASE_ADDR +  4)
#define MTIMECMP_LOW_ADDR  (TIMER_BASE_ADDR +  8)
#define MTIMECMP_HIGH_ADDR (TIMER_BASE_ADDR + 12)
#define MTIME_CTRL_ADDR    (TIMER_BASE_ADDR + 16)
#define COMMON_ADDR 0x7000


#define COMMON_ADDR 0x7000

int main() {

  init_uart(100000000/2, 3000000/2); // 50 MHz for simulation, 40 MHz for FPGA
  //Init OUTPUT_REG_ADDR

  *(uint32_t*)(MTIME_LOW_ADDR) = 0x0;
  *(uint32_t*)(MTIME_HIGH_ADDR) = 0x0;
// set mtimecmp to something non-zero
  *(uint32_t*)(MTIMECMP_LOW_ADDR) = 0x00000123;
  *(uint32_t*)(MTIMECMP_HIGH_ADDR) =0x0;
  *(uint32_t*)(COMMON_ADDR) = 0xFF;


  // init CLIC
  *(uint32_t*)(CLIC_BASE_ADDR) = 8;

  // Rise interrupt threshold before enabling global interrupts
  csr_write(CSR_MINTTHRESH, 0xFF);

  // enable global interrupts
  asm("csrsi mstatus, 8");

  // positive edge triggering
  set_trig(7, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);


  //csr_write(CSR_MTVEC, 0x1400);
  csr_write(CSR_MTVT, 0x1000);

  enable_vectoring(7);
  enable_int(7);
  set_priority(7, 0x88);




  //enable timer [bit 0] & set prescaler to 00F [bits 20:8]
  *(uint32_t*)(MTIME_CTRL_ADDR) = 0x00F01;


  csr_write(CSR_MINTTHRESH, 0x00);

  asm("wfi");

  while (1)
    if (*(uint32_t*)(COMMON_ADDR) == 0xFE) break;

  print_uart("Timer test [PASSED]\n");

}