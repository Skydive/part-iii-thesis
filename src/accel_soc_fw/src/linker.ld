OUTPUT_FORMAT("elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(crtStart) /* Symbol for entry point */

MEMORY {
  RAM      (rwx): ORIGIN = 0x80000000, LENGTH = 0x10000000
}

_stack_size = 0x10000; /* 64KB stack = 0x10000, 1MB stack = 0x100000 */

SECTIONS {
  .vector ORIGIN(RAM) : {
    *crt.o(.start_jump);
  } > RAM

  .stack (NOLOAD) : {
    . = ALIGN(16);
    PROVIDE (_stack_end = .);
    . = . + _stack_size;
    . = ALIGN(16);
    PROVIDE (_stack_start = .);
  } > RAM

  .data : {
    *(.rdata) /* global static data */
    *(.rodata .rodata.*)
    *(.data .data.*) /* initialised data */
    . = ALIGN(8);
    PROVIDE( __global_pointer$ = . + 0x800 );
    *(.sdata .sdata.*) /* small initialised data */
    . = ALIGN(8);
    *(.srodata .srodata.*) /* read-only initialised data */
  } > RAM

  .bss (NOLOAD) : {
		. = ALIGN(4);
		_bss_start = .;
    *(.sbss*) /* small uninitialised data */
    *(.bss .bss.*) /* uninitialised data */
    *(COMMON) /* common symbols */
		. = ALIGN(4);
		_bss_end = .;
  } > RAM

  .text : {
    *(.text);
    /* *(.text.*); */ /* seperate sections for static linked NewLib functions */
  } > RAM
}
