/*
  UART test code based on CVA6 reference
*/

#include <stdint.h>
#include "include/uart.h"

#define OUTPUT_REG_ADDR 0x00030008

int main(){

  init_uart(100000000, 9600); // 100 MHz for simulation, 40 MHz for FPGA

  print_uart("[UART] Hello from mock UART!\n");
  print_uart("[UART] UART_TEST [PASSED]\n");

  *(uint32_t*)(OUTPUT_REG_ADDR) = 1;
  while (1)
    ;
  
}
