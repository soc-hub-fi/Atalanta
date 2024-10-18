#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

#define ITER_CNT 10

// (pseudo)random data generation
uint32_t lfsr = 0xCAFEFACEu;
uint32_t bit;
uint32_t rand(){
  bit  = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5) ) & 1;
  return lfsr =  (lfsr >> 1) | (bit << 31);
}

uint32_t get_rand_addr(uint32_t range_start, uint32_t range_end, char alligned){
  uint32_t size = range_end - range_start;
  uint32_t result = (rand()%size) + range_start;
  if (alligned)
    result &= 0xFFFFFFFC;
  return result;
}

uint32_t error_count = 0;

uint32_t write_readback_word(uint32_t addr, volatile uint32_t value, char verbose){
  volatile uint32_t result = 0;
  // TODO: add prints
  if (verbose){
    print_uart("Writing value ");
    print_uart_int(value);
    print_uart(" to address ");
    print_uart_int(addr);
    print_uart("\n");
  }
  *(uint32_t*)(addr) = value;
  result = *(uint32_t*)(addr);
  if (verbose){
    print_uart("Read back ");
    print_uart_int(result);
    print_uart("\n");
  }
  if(result != value) {
    print_uart("ERROR: readback unsuccessful\n wrote ");
    print_uart_int(value);
    print_uart(", read ");
    print_uart_int(result);
    print_uart("\n");
    error_count++;
  }
  return result;
}

uint16_t write_readback_half(uint16_t addr, uint16_t value, char verbose){
  volatile uint16_t result = 0;
  // TODO: add prints
  *(uint16_t*)(addr) = value;
  result = *(uint16_t*)(addr);
  if(result != value) {
    print_uart("ERROR: readback unsuccessful\n wrote ");
    print_uart_int(value);
    print_uart(", read ");
    print_uart_int(result);
    print_uart("\n");
    error_count++;
  }
  return result;
}

uint8_t write_readback_byte(uint8_t addr, uint8_t value, char verbose){
  volatile uint8_t result = 0;
  // TODO: add prints
  *(uint8_t*)(addr) = value;
  result = *(uint8_t*)(addr);
  if(result != value) {
    print_uart("ERROR: readback unsuccessful\n wrote ");
    print_uart_int(value);
    print_uart(", read ");
    print_uart_int(result);
    print_uart("\n");
    error_count++;
  }
  return result;
}

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
  print_uart("[UART] Starting memory_sanity test\n");

  print_uart("[UART] Performing alligned word accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_word(get_rand_addr(0x5000, 0x9000, 1), rand(), 0);
  }

  print_uart("[UART] Performing unaligned word accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_word(get_rand_addr(0x5000, 0x9000, 0), rand(), 0);
  }

  print_uart("[UART] Performing alligned half-word accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_half(get_rand_addr(0x5000, 0x9000, 1), rand(), 0);
  }

  print_uart("[UART] Performing unaligned half-word accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_half(get_rand_addr(0x5000, 0x9000, 0), rand(), 0);
  }

    print_uart("[UART] Performing alligned byte accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_byte(get_rand_addr(0x5000, 0x9000, 1), rand(), 0);
  }

  print_uart("[UART] Performing unaligned byte accesses\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_byte(get_rand_addr(0x5000, 0x9000, 0), rand(), 0);
  }

  print_uart("[UART] Test complete, error count: ");
  print_uart_int(error_count);
  print_uart("\n");

  return error_count;

  //while (1)
  //  ; // keep test from returning

}