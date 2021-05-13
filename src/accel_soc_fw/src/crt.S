.global crtStart
.global main

.section	.start_jump,"ax",@progbits
crtStart:
  lui  x2,      %hi(crtInit)
  addi x2, x2,  %lo(crtInit)
  jalr x1, x2   // Jump to label crtInit
  nop

.section .text
crtInit:
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, _stack_start
  call main
infinitLoop:
  j infinitLoop
