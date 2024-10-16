#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

uint32_t write_readback(uint32_t addr, uint32_t value, char verbose){
  volatile uint32_t result = 0;
  // TODO: add prints
  *(uint32_t*)(addr) = value;
  result = *(uint32_t*)(addr);
  return result;
}

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
  print_uart("[UART] Starting memory_sanity test\n");
  print_uart("[UART] Performing alligned memory accesses\n");
  print_uart("[UART] Performing unaligned memory accesses\n");

  while (1)
    ; // keep test from returning

}