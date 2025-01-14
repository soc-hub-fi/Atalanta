/*
  Simple program to read button value in polling loop and light up
  matching LED on PYNQ-Z1 board.
*/

#include <stdint.h>

#define INPUT_REG_ADDR  0x00030004
#define OUTPUT_REG_ADDR 0x00030008

int main() {

volatile uint32_t in_reg = 0;

  while (1)
  {
    in_reg = *(uint32_t*)(INPUT_REG_ADDR);
    *(uint32_t*)(OUTPUT_REG_ADDR) = in_reg;
  }
}