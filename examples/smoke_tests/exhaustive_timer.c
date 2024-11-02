#include <stdint.h>

#include "include/common.h"
#include "include/clic.h"
#include "include/csr_utils.h"


#define N_SOURCE 63
#define NESTED_ARG_ADDR (0x5F00) // PENDING ARGUMEND VAR ADDRESS FOR NESTING 
#define NESTED_DEC_ADDR (0x5E00) // CONTROLS NESTING LEVELS
#define TIMER_BASE_ADDR    0x00030200
#define MTIME_LOW_ADDR     (TIMER_BASE_ADDR +  0)
#define MTIME_HIGH_ADDR    (TIMER_BASE_ADDR +  4)
#define MTIMECMP_LOW_ADDR  (TIMER_BASE_ADDR +  8)
#define MTIMECMP_HIGH_ADDR (TIMER_BASE_ADDR + 12)
#define MTIME_CTRL_ADDR    (TIMER_BASE_ADDR + 16)
#define COMMON_ADDR 0x7000

void irqs_config(){
     
    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);
    // Rise interrupt threshold before enabling global interrupts
    csr_write(CSR_MINTTHRESH, 0xFF);
    
    for(uint32_t id = 40; id < N_SOURCE  ; id++){
        if(id == 31 || id == 32 || id == 59){continue;} // reset handler shoudln't be accessed!
        else{                                           // Issue in line 59 

            /* enabling vectoring for interrupt lines */
            enable_vectoring(id);

            /* Set trigger type for interrupts  */
            set_trig(id, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);

            //priorities are set randomely 
            set_priority(id, (id+(id % 10)-5));  

            /*Enable interrupt*/
            enable_int(id); 

        }
    }

  
}

int main(){
    
    init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
    init(); //init shared variables
    
    *((uint32_t *)(NESTED_DEC_ADDR))  = 0x00000010; //control the nesting levels
    *((uint32_t *)(NESTED_ARG_ADDR))  = 0x00000028; //argument passed to pend_int to fire the next interrupt
    *(uint32_t*)(COMMON_ADDR) = 0xAA;

    
    irqs_config();

 

  // positive edge triggering
  set_trig(7, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);


  //csr_write(CSR_MTVEC, 0x1400);
  csr_write(CSR_MTVT, 0x1000);

  enable_vectoring(7);
  enable_int(7);
  set_priority(7, 0x88);


  

  //enable timer [bit 0] & set prescaler to 00F [bits 20:8]
  *(uint32_t*)(MTIME_CTRL_ADDR) = 0x00F01;

 // enable global interrupts
  asm("csrsi mstatus, 8");
  csr_write(CSR_MINTTHRESH, 0x00);


    while (1)
        if (*(uint32_t*)(NESTED_DEC_ADDR) == 0) break;

        uint16_t count = *((uint32_t *)(SHARED_VAR_ADDR));
        print_uart("Expected: ");    
        print_uart_int(0xF);
        print_uart("\n");
  
        print_uart("Actual: ");    
        print_uart_int(count);
        print_uart("\n");

        

        if(count!= 0xF){
            print_uart("[UART] Test [FAILED]\n");
            return 1;
        } else {
            print_uart("[UART] Test [PASSED]\n");
            return 0;
        }

}



