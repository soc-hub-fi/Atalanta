OUTPUT_ARCH(riscv)
SEARCH_DIR(.)
__DYNAMIC = 0;

MEMORY
{
  IMEM (rx ) : ORIGIN = 0x1000, LENGTH = 0x1000
  DMEM (rwx) : ORIGIN = 0x2000, LENGTH = 0x1000
}

STACK_SIZE = 0x400;

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.vectors .vectors.*))
    _stext = .;
    *(.text*)
    _etext = .;
    *(.rodata*)
  } > IMEM

  .bss (NOLOAD) :
  {
    *(.bss*)
    *(COMMON)
  } > DMEM

  .data : ALIGN(4)
  {
    *(.data*);
  } > IMEM

  .sdata : ALIGN(4)
  {
    *(.sdata*);
  } > IMEM
 
  .stack (NOLOAD) : 
  {
    . = ALIGN(4);
    stack = . + STACK_SIZE;
  } > DMEM

  _end = . ;
}
