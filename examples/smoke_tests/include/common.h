

#ifndef __COMMON_H__
#define __COMMON_H__


#include <stdint.h>

#include "uart.h"

#define LED_REG_ADDR (0x30008)
#define GPIO_REG_ADDR 0x00030008
#define SHARED_VAR_ADDR (0x2F00)


#define assert(expression)                                         \
	do {                                                           \
		if (!(expression)) {                                       \
			printf("%s:%d: assert error\n", __FILE__, __LINE__);   \
			exit(1);                                               \
		}                                                          \
	} while (0)



void delay(uint16_t iters){
    for(int i=0; i<iters; i++){}
}


void init(){
    *((uint32_t*)(LED_REG_ADDR)) = 0x00000000;   // TO AVOID RESETTING BETWEEN TESTS 
    *((uint32_t*)(LED_REG_ADDR)) = 0x00000100;   // LED1 SET

    asm("nop");
}


void test_complete(){
    volatile uint32_t reg = *((uint32_t*)(LED_REG_ADDR));
    reg = reg | 0x00000001;
    *((uint32_t*)(LED_REG_ADDR)) = reg;
}


void test_failed(){
    *((uint32_t*)(LED_REG_ADDR)) = 0x00000000;  // LED0 RESET : FAILURE!

    asm("nop");
}



// void mem_print(uint32_t addr_begin, uint32_t size){
//     uint32_t *p = (uint32_t *)addr_begin;
//     uint32_t reg = 0;

//     while(p < addr_begin + size){
//         reg = *p;

//         print_uart("[UART] Content of memory address # ");
//         print_uart_int((uint32_t)p);

//         print_uart(" =====> ");
//         print_uart_int(reg);
        
//         p++;
//     }
// }


#endif