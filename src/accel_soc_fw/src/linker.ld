OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(crtStart)
MEMORY {
  ROM      (rx):  ORIGIN = 0x80000000, LENGTH = 0x10000  /* 64KB */
  RAM      (rwx): ORIGIN = 0x80800000, LENGTH = 0x10000 /* 64KB */
}

_stack_size = 0x4000; /* 64KB stack = 0x10000, 1MB stack = 0x100000 */
SECTIONS {
  .vector ORIGIN(ROM) : {
    *crt.o(.start_jump);
  } > ROM AT > ROM

  .text : {
    *(.text);
    *(.rodata .rodata.*) /* Constants */
    *(.srodata .srodata.*) /* read-only initialised data */
    *(.text.*); /* seperate sections for static linked NewLib functions */
    *(.eh_frame)
    _rom_data_start = .;
  } > ROM
  
  .data : { /* initialised static variables */
    . = ALIGN(8) ;
    _ram_data_start = .;
    *(.rdata) /* global static data */
    *(.data .data.*) /* initialised data */
    PROVIDE( __global_pointer$ = . + 0x800 );
    *(.sdata .sdata.*) /* small initialised data */
    . = ALIGN(8);
    _ram_data_end = .;
  } > RAM AT > ROM
  _ram_data_size = _ram_data_end - _ram_data_start;

  .bss (NOLOAD) : { /* uninitialised static variables */
		. = ALIGN(4);
		_bss_start = .;
    *(.sbss*) /* small uninitialised data */
    *(.bss .bss.*) /* uninitialised data */
    *(COMMON) /* common symbols */
		. = ALIGN(4);
		_bss_end = .;
  } > RAM

  .stack (NOLOAD) : { /* stack location */
    . = ALIGN(16);
    _stack_end = .;
    . = . + _stack_size;
    . = ALIGN(16);
    _stack_start = .;
  } > RAM
}
