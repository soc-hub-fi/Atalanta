#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"
#include "include/clic.h"

#define UART_IRQ 17

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 30 MHz for FPGA

  //printf("[UART] Starting UART rx test\n");
  //printf("[UART] Waiting from input from TB\n");

  //set_trig(UART_IRQ, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
  //csr_write(CSR_MTVT, 0x1000);
  //enable_vectoring(UART_IRQ);
  //enable_int(UART_IRQ);
  //set_priority(UART_IRQ, 0x91);

  write_reg_u8(UART_INTERRUPT_ENABLE, 0x04); // RX interrupt 
  *(uint8_t*)(UART_INTERRUPT_IDENT) = 1u; // RX fifo reset


  //delay
  for (volatile uint32_t i = 0; i < 2000; i++);


  uint8_t tmp = *(uint8_t*)(UART_RBR);
  printf("[UART] RX char %d\n", tmp);
  ///*Enable global interrupts*/
  //csr_read_set(CSR_MSTATUS, (0x1 << 3));
  //asm("wfi");
}
