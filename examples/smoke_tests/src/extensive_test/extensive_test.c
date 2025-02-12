#include <stdint.h>
#include "../include/common.h"
#include "../include/clic.h"
#include "../include/csr_utils.h"


#define N_SOURCE 64
#define NESTED_ARG_ADDR (0x5F00) // PENDING ARGUMEND NESTING 
#define NESTED_DEC_ADDR (0x5E00) // DEC VARIABLE ADDRESS FOR NESTING 

void vectored_clic(){    
    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);

    for(uint32_t id = 16; id < N_SOURCE  ; id++){
      if(id == 31 || id == 32){continue;} // reset handler shoudln't be accessed!
       else{  

            /* enabling vectoring for interrupt lines */
            enable_vectoring(id);

            /* Set trigger type for interrupts  */
            set_trig(id, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
            set_priority(id, (id+(id % 10)-5));
    
            /*Enable global interrupts*/
            csr_read_set(CSR_MSTATUS, (0x1 << 3));

            /*Enable interrupt*/
            enable_int(id);

            pend_int(id);
            
            delay(100);
       }
    }
}

void nested_clic(){    
    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);
    
    for(uint32_t id = 40; id < N_SOURCE  ; id++){
      if(id == 31 || id == 32 ){continue;} // reset handler shoudln't be accessed!
       else{  

            /* enabling vectoring for interrupt lines */
            enable_vectoring(id);

            /* Set trigger type for interrupts  */
            set_trig(id, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);

            //priorities are set randomely 
            set_priority(id, (id+(id % 10)-5));  
    
            /*Enable global interrupts*/
            csr_read_set(CSR_MSTATUS, (0x1 << 3));

            /*Enable interrupt*/
            enable_int(id); 
       }
    }
    pend_int(40);


}

void priority_test(){

    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);

    /* enabling vectoring for interrupt lines */
    enable_vectoring(40);
    enable_vectoring(41);
    enable_vectoring(42);
    /* Set trigger type for interrupts  */
    set_trig(40, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
    set_trig(41, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
    set_trig(42, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);

    //priorities are set randomely 
    set_priority(40, 0x30); //nops
    set_priority(41, 0x40); //shouln't nop, pend immediately
    set_priority(42, 0x10); //complete all nops
    
    /*Enable global interrupts*/
    csr_read_set(CSR_MSTATUS, (0x1 << 3));

    /*Enable interrupt*/
    enable_int(40); 
    enable_int(41);
    enable_int(42);

    pend_int(40);
    delay(100);

}



int main(){   

    // set peripherals to half freq
    write_reg_u8(0x00030500, 0x2);
    init_uart(100000000/2, 3000000/2); // 50 MHz for simulation, 40 MHz for FPGA
    init(); //init shared variables


    *((uint32_t *)(NESTED_DEC_ADDR))  = 0x00000005; //control the nesting levels
    *((uint32_t *)(NESTED_ARG_ADDR))  = 0x00000028; //argument passed to pend_int to fire the next interrupt
    
    //asm("addi gp, x0, 0x500");
    //asm("slli gp, gp, 4");
    //asm("lw    t0, 0(gp)");
    //asm("addi    t0, t0, 0x001");
    //asm("sw    t0, 0(gp)");

    
    vectored_clic();

    //priority_test()
    //nested_clic();

    uint16_t count = *((uint32_t *)(SHARED_VAR_ADDR));
    print_uart("Expected: ");    
    print_uart_int(0x2D);
    print_uart("\n");
  
    print_uart("Actual: ");    
    print_uart_int(count);
    print_uart("\n");
    
    if(count != 0x2D){
        print_uart("[UART] Test [FAILED]\n");
        return 1;
    } else {
        print_uart("[UART] Test [PASSED]\n");
        return 0;
    }

   //test_complete();

    //uint16_t gpio = *(uint32_t*)(GPIO_REG_ADDR);
    //if (gpio == 0x101){
    //    print_uart("vectored_clic [PASSED]\n");
    //}else{
    //    print_uart("vectored_clic [FAILED]\n");
    //}
    //while (1)
    //    ; // keep test from returning

}



