/* Author: Henri Lunnikivi <henri.lunnikivi@tuni.fi> */

ENTRY(_start)

MEMORY
{
  /* LENGTH = 0x4000 = 16K */
  IMEM (rx ) : ORIGIN = 0x1000, LENGTH = 0x4000
  /* LENGTH = 0x4000 = 16K */
  DMEM (rwx) : ORIGIN = 0x5000, LENGTH = 0x4000
}

/* Regions are setup like in link.ld for rt-ss written by Antti Nurmi. I didn't put any more thought into it. */

REGION_ALIAS("REGION_TEXT", IMEM);
REGION_ALIAS("REGION_DATA", IMEM);

REGION_ALIAS("REGION_RODATA", DMEM);
REGION_ALIAS("REGION_BSS", DMEM);
REGION_ALIAS("REGION_HEAP", DMEM);
REGION_ALIAS("REGION_STACK", DMEM);

/* The simulator requires code to start from 0x1100 since that's how the hardware operates */
ASSERT(_start == 0x1100, "code must start from 0x1100 for simulator builds");

/* Provide handlers for the placeholder traps */
PROVIDE(_start_Sixteen_trap = _start_DefaultHandler_trap);
PROVIDE(_start_Seventeen_trap = _start_DefaultHandler_trap);
