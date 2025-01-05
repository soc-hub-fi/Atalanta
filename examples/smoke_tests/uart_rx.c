#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"
#include "include/clic.h"

#define UART_IRQ 17


int main() {  
  init_uart(100000000/2, 1500000); // 50 MHz for simulation, 30 MHz for FPGA

  write_reg_u8(UART_INTERRUPT_ENABLE, 0);
  write_reg_u8(UART_INTERRUPT_ENABLE, 0x1 << 0);  // enable Receiver data available interrupt and character timeout indication interrupt enable.

  //printf("[UART] Starting UART rx test\n");
  //printf("[UART] Waiting from input from TB\n");

  set_trig(UART_IRQ, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
  csr_write(CSR_MTVT, 0x1000);
  enable_vectoring(UART_IRQ);
  enable_int(UART_IRQ);
  set_priority(UART_IRQ, 0x91);

  // write_reg_u8(UART_INTERRUPT_ENABLE, 0x04); // RX interrupt 
  *(uint8_t*)(UART_INTERRUPT_IDENT) = 1u; // RX fifo reset
  write_reg_u8(UART_FIFO_CONTROL, 0b00000111);     // Enable FIFO, clear it, with 1-byte triggering threshold


  // printf("[UART] UART INITIALIZED \n");
  
  //delay
  //while(circular_buffer_size(&rx_circ_buffer) < 7);
  // while(!pattern_buffer_check_pattern(&payload_patt_buf)){
  //   volatile uint8_t a = payload_buffer[2];
  //   volatile uint8_t b = payload_buffer[1];
  //   volatile uint8_t c = payload_buffer[0];
  // }

  while(!pattern_buffer_check_pattern(&payload_patt_buf));

  for(int i=0; i<1000; i++){
    asm("nop");
  }


  write_reg_u8(UART_INTERRUPT_ENABLE, 0x2);
  print_uart("THE SIZE OF THE RX BUFFER IS: \n");  
  print_uart_int((uint32_t)circular_buffer_size(&rx_circ_buffer));
  print_uart("\n");
  print_uart("\n");

  print_uart("THE ELEMENTS OF THE RX BUFFER ARE: \n");  
  
  while(!circular_buffer_empty(&rx_circ_buffer)){
    print_uart_int((uint32_t)(circular_buffer_pop(&rx_circ_buffer)));
    print_uart(" ");
  }
  print_uart("\n");


  // uint8_t tmp = *(uint8_t*)(UART_RBR);
  // printf("[UART] RX char %d\n", tmp);
  ///*Enable global interrupts*/
  //csr_read_set(CSR_MSTATUS, (0x1 << 3));
  //asm("wfi");
}
