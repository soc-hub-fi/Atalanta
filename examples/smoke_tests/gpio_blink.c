#include <stdint.h>
#include "include/clic.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR 0x00030008

int main() {

  while (1)
  {
    *(uint32_t*)(OUTPUT_REG_ADDR) = 1;
    for (int it=0; it<10000000; it++) asm("nop");
    *(uint32_t*)(OUTPUT_REG_ADDR) = 0;
    for (int it=0; it<10000000; it++) asm("nop");
  }
}