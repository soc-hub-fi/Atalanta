#include <stdint.h>

#include "../include/clic.h"
#include "../include/csr_utils.h"


#define N_SOURCE 32

void init_clic(){
    for(uint32_t id=0; id<N_SOURCE; id++){
        set_priority(id, id+32);

        // positive edge triggering
        set_trig(id, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
        
        // Enable vectoring for interrrupt #id 
        enable_vectoring(id);
        enable_int(id);
    }
}


void main(){
    /*
        Enable all interrupts 
        Set triggering mode to positive edge
        Enable vectoring for all interrupts
        don't pend them yet
    */
    init_clic();

    /*Rise rt-ibex's interrupt threshold*/
    csr_write(CSR_MINTTHRESH, 0xff);
    
    /*Enable global interrupts in rt-ibex*/
    csr_read_set(CSR_MSTATUS, (0x1 << 3));



}