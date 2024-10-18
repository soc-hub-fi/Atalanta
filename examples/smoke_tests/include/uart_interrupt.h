#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "clic.h"
#include "csr_utils.h"
#include "circular_buffer.h"

#define UART_BASE 0x00030100

#define UART_RBR UART_BASE + 0
#define UART_THR UART_BASE + 0
#define UART_INTERRUPT_ENABLE UART_BASE + 4
#define UART_INTERRUPT_IDENT UART_BASE + 8
#define UART_FIFO_CONTROL UART_BASE + 8
#define UART_LINE_CONTROL UART_BASE + 12
#define UART_MODEM_CONTROL UART_BASE + 16
#define UART_LINE_STATUS UART_BASE + 20
#define UART_MODEM_STATUS UART_BASE + 24
#define UART_DLAB_LSB UART_BASE + 0
#define UART_DLAB_MSB UART_BASE + 4

//UART_LINE_NUM
#define UART_LINE_NUM      17

//STRUCT INSTANTIATION
#define UART_BUFFER_SIZE 30
uint8_t buffer[UART_BUFFER_SIZE];
struct circular_buffer tx_buffer = {.buffer = buffer, .size = UART_BUFFER_SIZE, .head = 0, .tail = 0};

//THIS FUBNCTION CONFIGURES UART
void write_reg_u8(uintptr_t addr, uint8_t value)
{
    volatile uint8_t *loc_addr = (volatile uint8_t *)addr;
    *loc_addr = value;
}

uint8_t read_reg_u8(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}

//Start transmission if no ongoing transmission && buffer is not empty 
void start_tx(uintptr_t addr) 
{
    volatile uint8_t *loc_addr = (volatile uint8_t *)addr; 
    if(!circular_buffer_empty(&tx_buffer)){
        *loc_addr = circular_buffer_pop(&tx_buffer);
    }
}
// called from actual uart handler in crt0
void uart_handler(){

    write_reg_u8(UART_INTERRUPT_ENABLE, 0x00); // Disable uart interrupts, will get enabled again only when a new character is pushed into buffer
    
    if(!circular_buffer_empty(&tx_buffer)){
        start_tx(UART_THR);
    }

}
void init_uart_irq()
{
    write_word(CLIC_BASE_ADDR, 0x8, 0xFFFFFFFF, 0);
    csr_write(CSR_MTVT, (uint32_t)0x1000);
    
    //config irq line 17 (uart handler) 
    enable_vectoring(UART_LINE_NUM);
    set_trig(UART_LINE_NUM, CLIC_TRIG_POSITIVE | CLIC_TRIG_EDGE);
    set_priority(UART_LINE_NUM, 0x88);  
  
    /*Enable global interrupts*/
    csr_read_set(CSR_MSTATUS, (0x1 << 3));
  
    /*Enable interrupt*/
    enable_int(UART_LINE_NUM); 

}

void init_uart(uint32_t freq, uint32_t baud)
{
    uint32_t divisor = freq / (baud << 4);
    
    write_reg_u8(UART_INTERRUPT_ENABLE, 0x00); // disable uart interrupt
    write_reg_u8(UART_LINE_CONTROL, 0x80);     // Enable DLAB (set baud rate divisor)
    write_reg_u8(UART_DLAB_LSB, divisor);         // divisor (lo byte)
    write_reg_u8(UART_DLAB_MSB, (divisor >> 8) & 0xFF);  // divisor (hi byte)
    write_reg_u8(UART_LINE_CONTROL, 0x03);     // 8 bits, no parity, one stop bit
    write_reg_u8(UART_FIFO_CONTROL, 0xC7);     // Enable FIFO, clear them, with 14-byte threshold
    write_reg_u8(UART_MODEM_CONTROL, 0x20);    // Autoflow mode

    //circular_buffer initialization
    //circular_buffer_init(&tx_buffer, buffer, UART_BUFFER_SIZE);
    
    //clic uart irq configuration
    init_uart_irq();
    
}

void write_serial(char a)
{

    while(circular_buffer_full(&tx_buffer)); // poll if buffer is full 
    
    write_reg_u8(UART_INTERRUPT_ENABLE, 0x00); // disable all interrupts

    circular_buffer_push(&tx_buffer, a);
    
    write_reg_u8(UART_INTERRUPT_ENABLE, 0x02); // Enable interrupt for uart only after pushing new character 

}

uint8_t bin_to_hex_table[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

void bin_to_hex(uint8_t inp, uint8_t res[2])
{   
    uint8_t inp_low = (inp & 0xf);
    uint8_t inp_high = ((inp >> 4) & 0xf);

    res[1] = inp_low < 10 ? inp_low + 48 : inp_low + 55;
    res[0] = inp_high < 10 ? inp_high + 48 : inp_high + 55;
}


void print_uart(const char *str)
{
    const char *cur = &str[0];
    while (*cur != '\0')
    {
        write_serial((uint8_t)*cur);
        ++cur;
    }
    
}

void print_uart_int(uint32_t addr)
{
    int i;
    for (i = 3; i > -1; i--)
    {
        uint8_t cur = (addr >> (i * 8)) & 0xff;
        uint8_t hex[2];
        bin_to_hex(cur, hex);
        write_serial(hex[0]);
        write_serial(hex[1]);
    }
}
/*
void print_uart_addr(uint64_t addr)
{
    int i;
    for (i = 7; i > -1; i--)
    {
        uint8_t cur = (addr >> (i * 8)) & 0xff;
        uint8_t hex[2];
        bin_to_hex(cur, hex);
        write_serial(hex[0]);
        write_serial(hex[1]);
    }
}
*/
void print_uart_byte(uint8_t byte)
{
    uint8_t hex[2];
    bin_to_hex(byte, hex);
    write_serial(hex[0]);
    write_serial(hex[1]);
}

