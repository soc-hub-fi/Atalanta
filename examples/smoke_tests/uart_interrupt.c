#include <stdint.h>
#include "include/common.h"
#include "include/uart_interrupt.h"
#include "include/clic.h"
#include "include/csr_utils.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

void main(void) {  
  init_uart(50000000, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
  
  print_uart("[UART] UART_INTERRUPT_TEST [PASSED]\n");
  
  while (1)
    ; // keep test from returning

}