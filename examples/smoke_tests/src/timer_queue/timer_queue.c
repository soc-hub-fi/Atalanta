#include <stdint.h>
#include "../include/clic.h"
#include "../include/csr_utils.h"
#include "../include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200
#define TQ_BASE_ADDR       0x00040000

#define MTIME_LOW_ADDR     (TIMER_BASE_ADDR +  0)
#define MTIME_HIGH_ADDR    (TIMER_BASE_ADDR +  4)
#define MTIMECMP_LOW_ADDR  (TIMER_BASE_ADDR +  8)
#define MTIMECMP_HIGH_ADDR (TIMER_BASE_ADDR + 12)
#define MTIME_CTRL_ADDR    (TIMER_BASE_ADDR + 16)
#define COMMON_ADDR 0x7000

#define MTIME_IRQ_ID 7

#define COMMON_ADDR 0x700


#define TQ_STATUS          (TQ_BASE_ADDR +  0)
#define TQ_LAST_PUSH       (TQ_BASE_ADDR +  4)
#define TQ_PUSH_REL        (TQ_BASE_ADDR +  8)
#define TQ_PUSH_ABS        (TQ_BASE_ADDR + 12)
#define TQ_DROP            (TQ_BASE_ADDR + 16)

int main() {

  // set peripherals to full freq
  write_reg_u8(0x00030500, 0x1);
  init_uart(100000000, 3000000); // 50 MHz for simulation, 40 MHz for FPGA

  // init CLIC – nr. level bits to 8
  *(uint32_t*)(CLIC_BASE_ADDR) = 8;

  // enable global interrupts
  asm("csrsi mstatus, 8");
  
  //enable timer [bit 0] & set prescaler to 3 [bits 10:8]
  *(uint32_t*)(MTIME_CTRL_ADDR) = 0x00301;

  // Read STATUS reg
  volatile uint32_t status = *(uint32_t*)(TQ_STATUS);

  // PUSH_REL ID 3
  *(uint32_t*)(TQ_PUSH_REL) = 0x03000000; // NOW
  *(uint32_t*)(TQ_PUSH_REL) = 0x03000010;
  *(uint32_t*)(TQ_PUSH_REL) = 0x04000010; // ID 4
  // PUSH_ABS ID 1
  *(uint32_t*)(TQ_PUSH_ABS) = 0x01000020;
  *(uint32_t*)(TQ_PUSH_ABS) = 0x01000123;
  *(uint32_t*)(TQ_PUSH_ABS) = 0x010FFFFF;
  // DROP last inserted entry
  *(uint32_t*)(TQ_DROP) = *(uint32_t*)(TQ_LAST_PUSH);

  // positive edge triggering
  set_trig(MTIME_IRQ_ID, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);


  //csr_write(CSR_MTVEC, 0x1400);
  csr_write(CSR_MTVT, 0x1000);

  //enable_vectoring(MTIME_IRQ_ID);
  //enable_int(MTIME_IRQ_ID);
  //set_priority(MTIME_IRQ_ID, 0x88);

  //csr_write(CSR_MINTTHRESH, 0x00);

  //asm("wfi");


  print_uart("AnTiQ test [PASSED]\n");

}
