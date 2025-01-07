#include <stdint.h>

#include "include/common.h"
#include "include/clic.h"
#include "include/csr_utils.h"


#define N_SOURCE 64
#define TIMESTAMPS_BASE (SHARED_VAR_ADDR + 4)



void exhaustive(){
    for(uint32_t id=0; id<N_SOURCE; id++){
        set_priority(id, id+32);

        // positive edge triggering
        set_trig(id, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);

        // Enable vectoring for interrrupt #id
        enable_vectoring(id);
        enable_int(id);
        pend_int(id);

        //delay(1);
    }

    // Reset to default state
    // No side-effects
    for(uint32_t id=0; id<N_SOURCE; id++){
       disable_int(id);
       disable_vectoring(id);
       set_priority(id, 0);
       ack_int(id);
       set_trig(id, 0);
    }

}



/*
    Setup interrupt nesting for CLIC test case
    INT31 :
        prio : 0xff (no interrupt priority is implemented in hw, all eight bits encode level)
    INT30 :
        prio : 0x88 (no interrupt priority is implemented in hw, all eight bits encode level)

*/
void nested_clic(){
    /* redirect vector table to our custom one */
	// clic_setup_mtvec();
	// clic_setup_mtvt();
    //csr_write(CSR_MTVEC, (uint32_t)0x3);
    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);

    /* enabling vectoring for both interrupt lines */
    enable_vectoring(29);
    enable_vectoring(30);

    /* Set trigger type for both interrupts  */
    /* Positive edge triggering is the only mode supported */
    set_trig(29, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
    set_trig(30, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);


    set_priority(30, 0x88);
    set_priority(29, 0xaa);

    /*Raise interrupt threshold in RT-Ibex before enabling interrupts*/
    csr_write(CSR_MINTTHRESH, 0xff);

    /*Enable global interrupts*/
    csr_read_set(CSR_MSTATUS, (0x1 << 3));



    /*Enable both interrupts*/
    enable_int(29);
    enable_int(30);

    /*Enable both interrupts*/
    /*No interrupt will fire yet*/
    pend_int(30);

    delay(100);

    pend_int(29);

    /*Start perf counter*/
    csr_read_clear(CSR_MCOUNTINHIBIT, 0x1);


    /*Lower interrupt threshold in RT-Ibex*/
    /*Interrupt should fire*/
    csr_write(CSR_MINTTHRESH, 0x00);

    delay(1000);
}


void stamp_print(uint32_t addr_begin, uint16_t num_stamps){
    uint32_t *p = (uint32_t *)addr_begin;
    uint32_t reg = 0;
    uint32_t count = 0;

    while(p < addr_begin + num_stamps * sizeof(uint64_t)){
        reg = *p;

        print_uart("[UART] Timestamp # ");
        print_uart_int(++count);
        print_uart(" ==============> ");
        print_uart_int(reg);

        reg = *(++p);
        print_uart_int(reg);
        print_uart(" Clock Cycles");
        print_uart("\n");

        p++;
    }
}


/*
    prints the timestamps of handler29
    Timestamps are dumped values of mcycle performance counter
    mcycle pause/resume events are highlighted in the function body (and the interrupt handler asm)
    Measurements on CLIC EABI show => 180 CCs of interrupt latency and 188 CCs of interrupt exit
    latency => from the time the interrupt signal fires, to the time the first intruction of the handler executes
    (the delay of registers context saving is included)
    Same for the interrupt exit

*/
void clic_perf(){


    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);

    /* enabling vectoring for both interrupt lines */
    enable_vectoring(29);

    /* Set trigger type for both interrupts  */
    /* Positive edge triggering is the only mode supported */
    set_trig(29, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);


    set_priority(29, 0xaa);

    /*Raise interrupt threshold in RT-Ibex before enabling interrupts*/
    csr_write(CSR_MINTTHRESH, 0xff);

    /*Enable global interrupts*/
    csr_read_set(CSR_MSTATUS, (0x1 << 3));


    /*Enable interrupt*/
    enable_int(29);

    /*Pend interrupt*/
    /*No interrupt will fire yet*/
    pend_int(29);

    /*Wait for clic to rise the interrupt line*/
    delay(10);


    /*Disable mcycle perf monitor (enabled by default at bootup/reset)*/
    csr_read_set(CSR_MCOUNTINHIBIT, 0x1);


    /*Initialize mcycle counter*/
    /*perf monitors are 64-bits for all risc-v ISA variants..*/
    /*Two csr instructions are requried*/
    csr_write(CSR_MCYCLE, 0);
    csr_write(CSR_MCYCLEH, 0);


    /*Initialize the first timestamp to 0*/
    *((volatile uint32_t *)(TIMESTAMPS_BASE)) = 0;
    *((volatile uint32_t *)(TIMESTAMPS_BASE + 4)) = 0;



    /*Start perf counter*/
    csr_read_clear(CSR_MCOUNTINHIBIT, 0x1);
//----------------------------------------------------------------> start mcycle perf monitor

    /*Lower interrupt threshold in RT-Ibex*/
    /*Interrupt should fire*/
    csr_write(CSR_MINTTHRESH, 0x00);

    while(!*((uint32_t *)(SHARED_VAR_ADDR))){}

//----------------------------------------------------------------> return from interrupt handler


    /*Disable mcycle perf monitor (enabled by default at bootup/reset)*/
    csr_read_set(CSR_MCOUNTINHIBIT, 0x1);
//----------------------------------------------------------------> Pause mcycle perf monitor

    /*
        store timestamps in big-endian
    */
    asm("csrr  t0, mcycleh");
    asm("sw    t0, 20(gp)");
    asm("csrr  t0, mcycle");
    asm("sw    t0, 24(gp)");

    asm("nop");

    init_uart(100000000, 9600);

    stamp_print(TIMESTAMPS_BASE, 3);

}



int main(){
    
    init_uart(100000000/2, 3000000); // 50 MHz for simulation, 40 MHz for FPGA
    init();

    //exhaustive();
    nested_clic();

    //clic_perf();

    uint8_t res = 0;
    uint16_t count = *((uint32_t *)(SHARED_VAR_ADDR));

    print_uart("[UART] Shared variable value is ");
    print_uart_int(count);
    print_uart("\n");

    if(count == 0){
        res = 1;
        print_uart("[UART] Test [FAILED]\n");
    } else {
        print_uart("[UART] Test [PASSED]\n");
    }
    
    return res;

}