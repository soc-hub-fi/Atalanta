/*
 * Copyright (C) 2021 ETH Zurich and University of Bologna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * Author(s): Robert Balas (balasr@iis.ee.ethz.ch)
 *            Abdesattar Kalache (abdesattar.kalache@tuni.fi)
 */

#ifndef __CLIC_H__
#define __CLIC_H__

/* Number of interrupt sources */
/* taken from target configuration */
/* #define CLIC_PARAM_NUM_SRC 256 */

/* Number of interrupt control bits */
/* taken from target configuration */
/* #define CLIC_PARAM_CLIC_INT_CTL_BITS 8 */

#define CLIC_BASE_ADDR  (0x00050000)

/* Register width */
#define CLIC_PARAM_REG_WIDTH 8

/* CLIC Configuration */
#define CLIC_CLICCFG_REG_OFFSET	 0x0
#define CLIC_CLICCFG_NVBITS_BIT	 0
#define CLIC_CLICCFG_NLBITS_MASK 0xf
#define CLIC_CLICCFG_NLBITS_OFFSET 1
#define CLIC_CLICCFG_NMBITS_MASK   0x3
#define CLIC_CLICCFG_NMBITS_OFFSET 5

/* CLIC Information */
#define CLIC_CLICINFO_REG_OFFSET	   0x4
#define CLIC_CLICINFO_NUM_INTERRUPT_MASK   0x1fff
#define CLIC_CLICINFO_NUM_INTERRUPT_OFFSET 0

#define CLIC_CLICINFO_VERSION_MASK   0xff
#define CLIC_CLICINFO_VERSION_OFFSET 13

#define CLIC_CLICINFO_CLICINTCTLBITS_MASK   0xf
#define CLIC_CLICINFO_CLICINTCTLBITS_OFFSET 21

#define CLIC_CLICINFO_NUM_TRIGGER_MASK	 0x3f
#define CLIC_CLICINFO_NUM_TRIGGER_OFFSET 25


/* CLIC Interrupt Trigger */
#define CLIC_INTTRIGG_REG_OFFSET(id) (0x0040 + 0x04 * id)
#define CLIC_INTTRIGG_ENABLE_BIT 31
#define CLIC_INTTRIGG_INT_NUMBER_OFFSET 0
#define CLIC_INTTRIGG_INT_NUMBER_MASK 0X00000FFF


/* CLIC Interrupt registers (4-bytes)*/
#define CLIC_INTREG_OFFSET(id) (0x1000 + 0x04 * id)


/* CLIC enable mnxti irq forwarding logic */
#define CLIC_CLICXNXTICONF_REG_OFFSET 0x8
#define CLIC_CLICXNXTICONF_CLICXNXTICONF_BIT 0

/* CLIC interrupt id pending */
#define CLIC_CLICINTIE_IP_BIT  0
#define CLIC_CLICINTIE_IP_MASK  0x1

/* CLIC interrupt id enable */
#define CLIC_CLICINTIE_IE_BIT  8
#define CLIC_CLICINTIE_IE_MASK  0x1

/* CLIC PCS id enable */
#define CLIC_CLICINTIE_PCS_BIT  12
#define CLIC_CLICINTIE_PCS_MASK  0x1

/* CLIC interrupt id attributes */
#define CLIC_CLICINTATTR_SHV_MASK 0x1 
#define CLIC_CLICINTATTR_SHV_BIT	16
#define CLIC_CLICINTATTR_TRIG_MASK	0x3
#define CLIC_CLICINTATTR_TRIG_OFFSET	17
#define CLIC_CLICINTATTR_MODE_MASK	0x3
#define CLIC_CLICINTATTR_MODE_OFFSET	22

#ifndef __ASSEMBLER__
enum clic_trig {
	CLIC_TRIG_LEVEL = 0,
	CLIC_TRIG_EDGE = 1,
	CLIC_TRIG_POSITIVE = 0 << 1,
	CLIC_TRIG_NEGATIVE = 1 << 1
} typedef clic_trig;
#endif

#define CLIC_NBTIS 8

/* CLIC interrupt id control */
#define CLIC_CLICINTCTL_CTL_MASK	  0xff
#define CLIC_CLICINTCTL_CTL_OFFSET 24 + (8 - CLIC_NBTIS)

#define CSR_MXNTI_ID       0x345
#define MIE                8



#include "stdint.h"

typedef uint32_t intId;


void write_word(uint32_t addr, int32_t val, uint32_t mask, uint32_t bit_pos){
    uint32_t tmp = *((volatile uint32_t *)(addr));
    tmp = tmp & (~(mask << bit_pos)); // Clear bitfields
    *((volatile uint32_t *)(addr)) = tmp | (val << bit_pos);
}


uint32_t read_word(uint32_t addr, uint32_t mask, uint32_t bit_pos){
    uint32_t reg = *((volatile uint32_t *)(addr));
    reg = (reg >> bit_pos) & mask; 
    return reg;
}


void enable_int(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x1, CLIC_CLICINTIE_IE_MASK, CLIC_CLICINTIE_IE_BIT);
}


void disable_int(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x0, CLIC_CLICINTIE_IE_MASK, CLIC_CLICINTIE_IE_BIT);
}

void enable_pcs(intId id) {
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x1, CLIC_CLICINTIE_PCS_MASK, CLIC_CLICINTIE_PCS_BIT);
}

void disable_pcs(intId id) {
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x0, CLIC_CLICINTIE_PCS_MASK, CLIC_CLICINTIE_PCS_BIT);
}

void pend_int(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x1, CLIC_CLICINTIE_IP_MASK, CLIC_CLICINTIE_IP_BIT);   
}


// Resets interrupt #id pending bit 
void ack_int(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x0, CLIC_CLICINTIE_IP_MASK, CLIC_CLICINTIE_IP_BIT);   
}



// Priority/Level [1, 2**NBITS]
void set_priority(intId id, uint32_t prio){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), prio, CLIC_CLICINTCTL_CTL_MASK, CLIC_CLICINTCTL_CTL_OFFSET);   
}


uint32_t get_priority(intId id){
    return read_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), CLIC_CLICINTCTL_CTL_MASK, CLIC_CLICINTCTL_CTL_OFFSET);
}


void set_trig(intId id, clic_trig trig){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), trig, CLIC_CLICINTATTR_TRIG_MASK, CLIC_CLICINTATTR_TRIG_OFFSET);
}


// Enable Vectored interrupt handling for interrupt #id
void enable_vectoring(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x1, CLIC_CLICINTATTR_SHV_MASK, CLIC_CLICINTATTR_SHV_BIT);
}


/* 
    Enable Vectored interrupt handling for interrupt #id
    CPU thus jumps to the common interrupt handler at xtvec
*/
void disable_vectoring(intId id){
    write_word(CLIC_BASE_ADDR + CLIC_INTREG_OFFSET(id), 0x0, CLIC_CLICINTATTR_SHV_MASK, CLIC_CLICINTATTR_SHV_BIT);
    
}

#endif