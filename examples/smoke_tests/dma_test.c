#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define DMA_SRC 0x00005000
#define DMA_DST 0x00020000
#define DMA_LEN 0x200

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 30 MHz for FPGA
  print_uart("[UART] DMA test init: populate src buffer\n");
  init_buffer(DMA_SRC, DMA_LEN);

  print_uart("[UART] Call DMA transfer\n");
  dma_transfer(DMA_SRC, DMA_DST, DMA_LEN);

  print_uart("[UART] DMA test check: compare src and dst buffers\n");
  cmp_buffer(DMA_SRC, DMA_DST, DMA_LEN);
}
