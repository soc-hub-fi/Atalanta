// ------------------------------------------------------------------------------
// System-Level Tests for CI CSR Functionality Testing 
//
// Author(s): Abdesattar Kalache <abdesattar.kalache@tuni.fi>
// Date     : 25-jan-2024
//
// Description: 
// ------------------------------------------------------------------------------

/*
    The tests written for RVG Calling Convention 
    Each CSR test corresponds to one C/asm leaf subroutine
    For simpler CSRs (mstatus, misa, ...), CSR is read/read-write, if the CSR value != RESET_VALUE,
    Dirty hack around riscv32-unknown-elf-gcc RVG calling convention : For the case of asm("") based tests, 
    assign the "failure" value to a5, it will then be assigned to a0 and consequently returned by the function call
    of directly a0 to hack-around 
*/


// For FPGA/Questa CI testing : two LEDS are used
///// LED0 => TESTS are complete (initially reset)
///// LED1 => NO FAILURES (initially Set)
///////// TEST SUCCESS = LED0 and LED1




#include <stdint.h>

#include "../include/common.h"
#include "../include/clic.h"
#include "../include/csr_utils.h"

//#define LED_REG_ADDR (0x00030008)
#define CLIC_BASE (0x00050000)
#define CLIC 1


// static inline void init(){
//     *((uint32_t*)(LED_REG_ADDR)) = 0x00000000;   // TO AVOID RESETTING BETWEEN TESTS 
//     *((uint32_t*)(LED_REG_ADDR)) = 0x00000100;   // LED1 SET

//     asm("nop");
// }


// static inline void test_failed(){
//     *((uint32_t*)(LED_REG_ADDR)) = 0x00000000;  // LED0 RESET : FAILURE!

//     asm("nop");
// }


// static inline void test_complete(){
//     volatile uint32_t reg = *((uint32_t*)(LED_REG_ADDR));
//     reg = reg | 0x00000001;
//     *((uint32_t*)(LED_REG_ADDR)) = reg;
// }


uint32_t __misa__(uint32_t reset_value){
    asm("nop");
    asm("csrr t0, misa");
    asm("xor t1, t0, a0");
    asm("add a5, zero, t1");     
    asm("nop");

}

uint32_t __mstatus__(uint32_t reset_value){
  
    uint32_t failure = 0;

    // Test MSTATUS reset value
    uint32_t mstatus = csr_read(CSR_MSTATUS);
    failure = failure | (mstatus != reset_value);
    
    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MSTATUS TEST FAILED \n");
    #endif

    return failure;
}



uint32_t __mcause__(uint32_t reset_value){
    uint32_t failure = 0;

    uint32_t mcause = csr_read(CSR_MCAUSE);
    failure = failure | (mcause != reset_value);

    #ifdef CLIC
        const uint32_t mpp = 0x3;
        const uint32_t mpie = 0x1;

        csr_read_set(CSR_MSTATUS, (mpp << 11)| (mpie << 7));
        mcause = csr_read(CSR_MCAUSE); 
        failure = failure | ((mcause >> 28 & 3) != mpp);
        failure = failure | ((mcause >> 27 & 1) != mpie);

        csr_read_clear(CSR_MSTATUS, (mpp << 11)| (mpie << 7));
        mcause = csr_read(CSR_MCAUSE);
        failure = failure | ((mcause >> 28 & 3) != 0);
        failure = failure | ((mcause >> 27 & 1) != 0);
    #endif

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MCAUSE TEST FAILED \n");
    #endif

    return failure;  
}


uint32_t __minthresh__(uint32_t reset_value){
    uint32_t failure = 0;

    // check for reset (should be 0)
    uint32_t minthresh = csr_read(CSR_MINTTHRESH);
    failure = failure | (minthresh != reset_value);

    uint32_t val = 0xFFAA;

    csr_write(CSR_MINTTHRESH, val);
    uint32_t cmp = csr_read(CSR_MINTTHRESH);
    csr_write(CSR_MINTTHRESH, 0);   //reset threshold

    failure = failure | (cmp != val & 0xFF);

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MINTHRESH TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mie__(uint32_t reset_value){
    uint32_t failure = 0;

    // check for reset (should be 0)
    uint32_t mie = csr_read(CSR_MIE);
    failure = failure | (mie != reset_value);


    uint32_t val = (3 << 0x1) | (7 << 0x1) | (11 << 0x1);  // Software, timer, external timer enable bits are set
    csr_write(CSR_MIE, val); /// Enable all interrupts
    mie = csr_read(CSR_MIE);

    #ifdef CLIC
        failure = failure | (mie != 0);   // Writes to mie are ignored while in CLIC mode
                                          // Reads always yield 0 even if MIE was set before CLIC 
                                         // mode was enabled
    #else 
        failure = failure | (mie != val);
    #endif 

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MIE TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mclicbase__(uint32_t reset_value){
    uint32_t failure = 0;
    
    uint32_t clic_base = csr_read(CSR_MCLICBASE);
    
    failure = failure | (reset_value != clic_base);

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MCLICBASE TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mtvec__(uint32_t reset_value){
    // All mtvec reset values are accepted 
    // As long as mtvec[1:0]=2'b11
    // Normally mtvec.BASE (mtvec[31:2]) points to
    // BOOTROM address aligned to 256-byte immediately after reset
    // mtvec.BASE should be writable (points to the base address of irq_handler(s) in direct and vectored modes)

    uint32_t failure = 0;
    const uint32_t clic_mode = 0x3;

    uint32_t mtvec = csr_read(CSR_MTVEC);
    failure = failure | ((mtvec & 0x00000003) != clic_mode);

    uint32_t val = 0xBADC0FFE | clic_mode;  // preserve clic mode
    csr_write(CSR_MTVEC, val);
    mtvec = csr_read(CSR_MTVEC);

    failure = failure | (mtvec != (val & 0xFFFFFF00 | clic_mode));

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MTVEC TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mtvt__(uint32_t reset_value){
    uint32_t failure = 0;
    const uint32_t val = 0xFFFFFFFF;    // mtvt[31:8] bits are writable by software 

    uint32_t mtvt = csr_read_set(CSR_MTVT, val);  // clears csr_mtvec_init_i
    failure = failure | (mtvt != reset_value);

    mtvt = csr_read(CSR_MTVT);
    failure = failure | (mtvt != ((val & 0xFFFFFF00) | 0x00000003));

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MTVT TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mepc__(uint32_t reset_value){
    uint32_t failure = 0;
    const uint32_t val = 0xFFFFFFFF;   

    uint32_t mepc = csr_read_set(CSR_MEPC, val);
    failure = failure | (mepc != reset_value);

    mepc = csr_read(CSR_MEPC);
    failure = failure | (mepc != (val & 0xFFFFFFFE));  // All bits are writable by software except for mepc[0] (compressed instructions supported by the ibex)
   
    csr_write(CSR_MEPC, reset_value);   // Reset mepc

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MEPC TEST FAILED \n");
    #endif

    return failure;
}


uint32_t __mintstatus__(uint32_t reset_value){
    uint32_t failure = 0;
    const uint32_t val = 0xFFFFFFFF;   

    uint32_t mintstatus = csr_read_set(CSR_MINTSTATUS, val);
    failure = failure | (mintstatus != reset_value);

    mintstatus = csr_read(CSR_MINTSTATUS);
    failure = failure | (mintstatus != val);  // All bits are writable by software (all priv levels and reseved bits)
                                              
    csr_write(CSR_MINTSTATUS, reset_value);   // Reset mintstatus

    #ifdef UART_PRINTS
    if(failure)
        print_uart("CSR_MINTSTATUS TEST FAILED \n");
    #endif

    return failure;
}


// todo : MNXTI tests

/*
    mip CSR is purely combinational
    Reads/writes should be ignored in CLIC mode
    Can't be overwritten explicitly with CSR instructions
*/
uint32_t __mip__(uint32_t reset_value){
    uint32_t failure = 0;
    uint32_t mip;
    
    mip = csr_read(CSR_MIP);

    #ifdef CLIC           
        failure = failure | (mip != 0);
    #endif

    return failure;
}



#define NUM_TESTS (11)


int main(){

    const uint32_t reset_values[NUM_TESTS] = 
    {
        0x00001880, 
        0x40101014, 
        0x38000000, 
        0x00000000, 
        0x00000000, 
        CLIC_BASE,
        0x00000000, 
        0x00000000,
        0x00000000,
        0x00000000,
        0x00000000
    };
    

    const uint32_t (*test_ptr[NUM_TESTS])() = 
    {
        __mstatus__, 
        __misa__, 
        __mcause__, 
        __minthresh__, 
        __mie__, 
        __mclicbase__, 
        __mtvec__, 
        __mtvt__, 
        __mepc__, 
        __mintstatus__,
        __mip__
    };


    init();


    uint32_t ret __attribute__((aligned(4))) = 0;
    uint32_t errors = 0;

    for(int i=0; i<NUM_TESTS; i++){
        ret = (*test_ptr[i])(reset_values[i]);
        if(ret){
            errors++;
        }
    }

    // set peripherals to half freq
    write_reg_u8(0x00030500, 0x2);
    init_uart(100000000/2, 3000000/2); // 50 MHz for simulation, 30 MHz for FPGA

    if (errors == 0)
        print_uart("[UART] CSR tests [PASSED]\n");
    else {
        print_uart("[UART] CSR tests [PASSED]\n");
    }

    return errors;

}