#include <stdint.h>
#include "include/clic.h"
#include "include/csr_utils.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

#define MTIME_LOW_ADDR     (TIMER_BASE_ADDR +  0)
#define MTIME_HIGH_ADDR    (TIMER_BASE_ADDR +  4)
#define MTIMECMP_LOW_ADDR  (TIMER_BASE_ADDR +  8)
#define MTIMECMP_HIGH_ADDR (TIMER_BASE_ADDR + 12)
#define MTIME_CTRL_ADDR    (TIMER_BASE_ADDR + 16)

int main() {

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


  // set mtimecmp to something non-zero
  *(uint32_t*)(MTIMECMP_LOW_ADDR) = 0x00000123;

  //enable timer [bit 0] & set prescaler to 00F [bits 20:8]
  *(uint32_t*)(MTIME_CTRL_ADDR) = 0x00F01;


  csr_write(CSR_MINTTHRESH, 0x00);

  // delay
  for (int it=0; it<100; it++){
    volatile uint32_t dummy_load = *(uint32_t*)(MTIMECMP_LOW_ADDR);
    uint32_t reg = 2 / dummy_load;
    reg *= 7;
  }

  //terminate test
  //*(uint32_t*)(OUTPUT_REG_ADDR) = 1;
  while (1)
    ;
  
}