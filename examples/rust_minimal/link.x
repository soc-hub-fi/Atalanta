_hart_stack_size = 0x400;

MEMORY
{
  /* Instruction memory : 0x4000 = 16 KiB */
  IMEM (rx ): ORIGIN = 0x1000, LENGTH = 0x4000
  /* Data memory        : 0x4000 = 16 KiB */
  DMEM (rwx): ORIGIN = 0x5000, LENGTH = 0x4000
}

REGION_ALIAS("REGION_STACK", DMEM);

PROVIDE(_stack_start = ORIGIN(REGION_STACK) + LENGTH(REGION_STACK));

ENTRY(reset)

SECTIONS
{
  .vectors ORIGIN(IMEM) :
  {
    KEEP(*(.vectors));
  } > IMEM

  .text :
  {
    . = ORIGIN(IMEM) + 0x80;
    _stext = .;
    KEEP(*(.init));
    *(.text .text.*);
    _etext = .;
    *(.rodata*)
  } > IMEM

  /* fictitious region that represents the memory available for the stack */
  .stack (NOLOAD) :
  {
    _estack = .;
    . = ABSOLUTE(_stack_start);
    _sstack = .;
  } > REGION_STACK
}

/* The simulator requires code to start from 0x1080 due to use of stim files */
ASSERT(reset == 0x1080, "code must start from 0x1080 for simulator builds");
