/* Author: Henri Lunnikivi <henri.lunnikivi@tuni.fi> */

/* Reduce stack size from 2K to 1K (=0x400) because rt-ss really has none to spare */
_hart_stack_size = 0x400;

ENTRY(_start)

MEMORY
{
  /* LENGTH = 0x1000 = 4K */
  IMEM (rx ) : ORIGIN = 0x1000, LENGTH = 0x1000
  /* LENGTH = 0x1000 = 4K */
  DMEM (rwx) : ORIGIN = 0x2000, LENGTH = 0x1000
}

/* Regions are setup like in link.ld for rt-ss written by Antti Nurmi. I didn't put any more thought into it. */

REGION_ALIAS("REGION_TEXT", IMEM);
REGION_ALIAS("REGION_DATA", IMEM);

REGION_ALIAS("REGION_RODATA", DMEM);
REGION_ALIAS("REGION_BSS", DMEM);
REGION_ALIAS("REGION_HEAP", DMEM);
REGION_ALIAS("REGION_STACK", DMEM);

/* The simulator requires code to start from 0x1080 due to use of stim files */
ASSERT(_start == 0x1080, "code must start from 0x1080 for simulator builds");
