#include <stdint.h>
#include <stdarg.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define DMA_SRC 0x00005000
#define DMA_DST 0x00020000
#define DMA_LEN 0x200

void init_buffer( uint32_t* src, uint32_t len){
  printf("Test %x String %x \n", 0x2d, 0xff);
}	

void dma_transfer( uint32_t* src, uint32_t* dst, uint32_t len){

}

int cmp_buffer( uint32_t* src, uint32_t* dst, uint32_t len){
  for (uint32_t i=0; i<len; i = i + 4){
    volatile uint32_t src_val = *(uint32_t*)(src + i);   
    volatile uint32_t dst_val = *(uint32_t*)(dst + i);   
    if (src_val != dst_val){
      printf("[UART] SRC-DST mismatch! SRC: 0x%x, DST 0x%x\n", src_val, dst_val);
      return 1; 
    }
  }
  printf("[UART] No mismatches, test [PASSED]\n");
}

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 30 MHz for FPGA
  printf("[UART] DMA test init: populate src buffer\n");
  init_buffer(DMA_SRC, DMA_LEN);

  printf("[UART] Call DMA transfer\n");
  dma_transfer(DMA_SRC, DMA_DST, DMA_LEN);

  printf("[UART] DMA test check: compare src and dst buffers\n");
  return cmp_buffer(DMA_SRC, DMA_DST, DMA_LEN);

}
