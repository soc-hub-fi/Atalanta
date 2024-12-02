// Perform memory accessess of varying allingment and size to data memory, check result

#include <stdint.h>
#include "include/csr_utils.h"
#include "include/uart_interrupt.h"

#define OUTPUT_REG_ADDR    0x00030008
#define TIMER_BASE_ADDR    0x00030200

#define ITER_CNT 20
#define RANGE_TOP 0x6000
#define RANGE_BTM 0x5000
#define SRAM_BTM 0x20000
#define SRAM_TOP 0x30000

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
    printf("Writing value %x to address %x\n", value, addr);
  }
  *(uint32_t*)(addr) = value;
  result = *(uint32_t*)(addr);
  if (verbose){
    printf("Read back %x\n", result);
  }
  if(result != value) {
    printf("ERROR: readback unsuccessful\n wrote %x, read %x\n", value, result);
    error_count++;
  }
  return result;
}

uint16_t write_readback_half(uint32_t addr, uint16_t value, char verbose){
  volatile uint16_t result = 0;
  // TODO: add prints
  *(uint16_t*)(addr) = value;
  result = *(uint16_t*)(addr);
  if(result != value) {
    printf("ERROR: readback unsuccessful\n wrote %x, read %x\n", value, result);
    error_count++;
  }
  return result;
}

uint8_t write_readback_byte(uint32_t addr, uint8_t value, char verbose){
  volatile uint8_t result = 0;
  // TODO: add prints
  if (verbose){
    printf("Writing value %x to address %x\n", value, addr);
  }
  *(uint8_t*)(addr) = value;
  result = *(uint8_t*)(addr);
  if (verbose){
    printf("Read back %x\n", result);
  }
  if(result != value) {
    printf("ERROR: readback unsuccessful\n wrote %x, read %x\n", value, result);
    error_count++;
  }
  return result;
}

int main() {  
  init_uart(100000000/2, 3000000); // 50 MHz for simulation, 30 MHz for FPGA
  print_uart("[UART] Starting memory_sanity test\n");

  // Software utilizes SPMs too much to test SPMs with software
  //print_uart("[UART] Performing alligned word accesses to SPM\n");
  //for (int it=0; it<ITER_CNT; it++){
  //  write_readback_word(get_rand_addr(RANGE_BTM, RANGE_TOP, 1), rand(), 1);
  //}

  print_uart("[UART] Performing alligned word accesses to SRAM\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_word(get_rand_addr(SRAM_BTM, SRAM_TOP, 1), rand(), 0);
  }

  print_uart("[UART] Performing unaligned byte accesses to SRAM\n");
  for (int it=0; it<ITER_CNT; it++){
    write_readback_byte(get_rand_addr(SRAM_BTM, SRAM_TOP, 0), (uint8_t)rand(), 0);
  }

  printf("[UART] Test complete, error count: %x\n", error_count);
  if (error_count == 0)
    print_uart("[PASSED]\n");

  return error_count;

}