#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
  print_uart("[UART] Hello from UART!\n");
  print_uart("[UART] uart__sanity [PASSED]\n");
}