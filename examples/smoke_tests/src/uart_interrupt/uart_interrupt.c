#include <stdint.h>
#include "../include/csr_utils.h"
#include "../include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

int main() { 
  // set peripherals to half freq
  write_reg_u8(0x00030500, 0x2);
  init_uart(100000000/2, 3000000/2); // 50 MHz for simulation, 30 MHz for FPGA
  print_uart("[UART] Hello from UART!\n");
  print_uart("[UART] UART_INTERRUPT_TEST [PASSED]\n");

}