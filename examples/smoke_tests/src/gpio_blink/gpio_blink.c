#include <stdint.h>
#include "../include/clic.h"
#include "../include/uart_interrupt.h"

#define GPIO_BASE       0x00030000
#define PADDIR_00_31   (GPIO_BASE + 0x0)
#define GPIO_EN_00_31  (GPIO_BASE + 0x4)
#define PADIN_00_31    (GPIO_BASE + 0x8)
#define PADOUT_00_31   (GPIO_BASE + 0xC)
#define INTEN_00_31    (GPIO_BASE + 0x18)

int main() {

  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
  print_uart("[UART] Performing GPIO test\n");

  // enable clocks for gpios 0-3
  *(uint32_t*)(GPIO_EN_00_31) = 0xf;
  
  // set gpios 0-3 to output
  *(uint32_t*)(PADDIR_00_31) = 0xf;

  for (int i=0; i<10; i++){
    *(uint32_t*)(PADOUT_00_31) = 0xf;
    *(uint32_t*)(PADOUT_00_31) = 0x0;
  }

}