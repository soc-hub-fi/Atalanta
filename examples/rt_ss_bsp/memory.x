/* Author: Henri Lunnikivi <henri.lunnikivi@tuni.fi> */

ENTRY(_start)

MEMORY
{
  /* LENGTH = 0x4000 = 16K */
  IMEM (rx ) : ORIGIN = 0x1000, LENGTH = 0x4000
  /* LENGTH = 0x4000 = 16K */
  DMEM (rwx) : ORIGIN = 0x5000, LENGTH = 0x4000
  /* LENGTH = 0x10000 = 64K */
  SRAM (rwx) : ORIGIN = 0x20000, LENGTH = 0x10000
}

/* Regions are setup like in link.ld for rt-ss written by Antti Nurmi. I didn't put any more thought into it. */

REGION_ALIAS("REGION_TEXT", IMEM);

REGION_ALIAS("REGION_RODATA", DMEM);
REGION_ALIAS("REGION_BSS", DMEM);
REGION_ALIAS("REGION_HEAP", DMEM);
REGION_ALIAS("REGION_STACK", DMEM);

REGION_ALIAS("REGION_DATA", SRAM);

/* The simulator requires code to start from 0x1100 since that's how the hardware operates */
ASSERT(_start == 0x1100, "code must start from 0x1100 for simulator builds");

/* Default interrupt trap entry point. When vectored trap mode is enabled,
   the riscv-rt crate provides an implementation of this function, which saves caller saved
   registers, calls the the DefaultHandler ISR, restores caller saved registers and returns.
*/
/*
PROVIDE(_start_DefaultHandler_trap = _start_trap);
*/

/* When vectored trap mode is enabled, each interrupt source must implement its own
   trap entry point.

   The following default handlers are set by riscv-rt/link.rx:
*/
/*
PROVIDE(_start_SupervisorSoft_trap = _start_DefaultHandler_trap);
PROVIDE(_start_MachineSoft_trap = _start_DefaultHandler_trap);
PROVIDE(_start_SupervisorTimer_trap = _start_DefaultHandler_trap);
PROVIDE(_start_MachineTimer_trap = _start_DefaultHandler_trap);
PROVIDE(_start_SupervisorExternal_trap = _start_DefaultHandler_trap);
PROVIDE(_start_MachineExternal_trap = _start_DefaultHandler_trap);
*/

/* Provide default handlers for vectored traps */
PROVIDE(_start_Uart_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Gpio_trap = _start_DefaultHandler_trap);
PROVIDE(_start_SpiRxTxIrq_trap = _start_DefaultHandler_trap);
PROVIDE(_start_SpiEotIrq_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer0Ovf_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer0Cmp_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer1Ovf_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer1Cmp_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer2Ovf_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer2Cmp_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer3Ovf_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Timer3Cmp_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Nmi_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma0_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma1_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma2_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma3_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma4_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma5_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma6_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma7_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma8_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma9_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma10_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma11_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma12_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma13_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma14_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Dma15_trap = _start_DefaultHandler_trap);
