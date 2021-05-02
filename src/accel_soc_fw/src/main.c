#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include "libc.h"
#include "accelerator.h"
#include "printf.h"
#include "test.h"


#define TEST_FLOAT


#define MSTATUS_FS          0x00006000
#define write_csr(reg, val) ({                            \
      asm volatile ("csrw " #reg ", %0" :: "rK"(val)); })
#define read_csr_safe(reg) ({ register long __tmp asm("a0");  \
      asm volatile ("csrr %0, " #reg : "=r"(__tmp));          \
      __tmp; })

void mstatus_init() {
  uintptr_t mstatus = 0;
  mstatus |= MSTATUS_FS;

  write_csr(mstatus, mstatus);
  #ifdef TEST_FLOAT
  float a = 1.0f;
  float b = 5.5f;
  printf("A: %.2f\n", a+b);
  #endif
}


float stack_mat_a[64*4];
float stack_mat_b[4*64];
void init_stack() {
  for(int i=0; i<sizeof(stack_mat_a)/sizeof(stack_mat_a[0]); i++)
    stack_mat_a[i] = 4.0;
  for(int i=0; i<sizeof(stack_mat_b)/sizeof(stack_mat_b[0]); i++)
    stack_mat_b[i] = -2.0;
}

// TODO: Unbuffered benchmarks
// Unbuffered:
// (GCC 9.2.0 riscv64-unknown-elf -O2 -march=rv32imafc -mabi )
// Sequential: ?/21500
//  1: 14866/15458
//  2: 
//  4: 
//  8:
// 12: 3968/3493
// 16:
// Overhead (CPC): 4994


#define ACCEL_UNITS 8
// Unbuffered: Firmware scheduling:
// (GCC 9.2.0 riscv64-unknown-elf -O2 -fno-inline -march=rv32imafc -mabi=ilp32f)
// Sequential: ?/21383
// 1 unit:  14658/15155
// 2 units:  7572/ 7957
// 4 units:  4247/ 4844
// 8 units:  3986/ 4570
// 12 units: 4133/ 4707
// 16 units: 3946/ 4581
// Overhead (CPC): 4982
// Overhead (BCC):    0
void accel_unbuffered_test() {
  uint32_t time0, time1;
  uint8_t count = 64;
  uint8_t cw = 4;
  uintptr_t ptr_a_addr = accel_malloc(sizeof(stack_mat_a)/sizeof(float));
  uintptr_t ptr_b_addr = accel_malloc(sizeof(stack_mat_b)/sizeof(float));
  float* ptr_c_addr = (float*)accel_malloc(4);

  time0 = read_csr_safe(cycle);
  memcpy((void*)ptr_a_addr, &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)ptr_b_addr, &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)ptr_c_addr, 0, 4*4*sizeof(float));
  time1 = read_csr_safe(cycle);
  printf("Copy cycles: %d\n", time1-time0-30);

  uint16_t busy_bits;
  time0 = read_csr_safe(cycle);
  for(int i=0; i<16; i++) {
    if(i%ACCEL_UNITS == 0) {
      do {
        busy_bits = *(uint16_t volatile*)ACCEL_BUSY_ADDR;
      } while(busy_bits & (1 << (i%ACCEL_UNITS)) > 0);
    }
    uint8_t x = i % cw;
    uint8_t y = i / cw;
    struct MatUnitArgs arg = {
      .unit = i % ACCEL_UNITS,
      .count = count,
      .ptr_a = {.addr = ptr_a_addr, .offset = count*y, .stride = 1},
      .ptr_b = {.addr = ptr_b_addr, .offset = x, .stride = cw},
      .ptr_c = {.addr = (uintptr_t)&ptr_c_addr[i], .offset = 0, .stride = 0},
    };
    accel_load_command(arg);
    accel_exec_command();
  }
  while(busy_bits = *(uint16_t volatile*)ACCEL_BUSY_ADDR != 0);
  time1 = read_csr_safe(cycle);
  printf("Time taken: %d\n", time1-time0-30);
  for(int i=0; i<16; i++)
    printf("Output: 0x%X -> %2.f\n", &((float*)ptr_c_addr)[i], ((float*)ptr_c_addr)[i]);
}


// Buffered: Firmware scheduling:
// (GCC 9.2.0 riscv64-unknown-elf -O2 -fno-inline -march=rv32imafc -mabi=ilp32f)
// Sequential: ?/21383
// 1 unit:  14658/15155
// 2 units:  7458/ 7957
// 4 units:  4050/ 4651
// 8 units:  3855/ 4351
// 12 units: 3989/ 4520

// 16 units: 3955/ 3329
// Overhead (CPC): 4982
// Overhead (BCC):  696
void accel_buffered_test() {
  uint32_t time0, time1;
  uint8_t count = 64;
  uint8_t cw = 4;
  float* ptr_a_addr = (float*)accel_malloc(sizeof(stack_mat_a)/sizeof(float));
  float* ptr_b_addr = (float*)accel_malloc(sizeof(stack_mat_b)/sizeof(float));
  float* ptr_c_addr = (float*)accel_malloc(4);

  time0 = read_csr_safe(cycle);
  time1 = read_csr_safe(cycle);
  uint32_t ct = time1-time0;
  printf("CSR Cycle Calibration: %d\n", time1-time0);
  
  time0 = read_csr_safe(cycle);
  /* for(int i=0; i<sizeof(stack_mat_a)/sizeof(stack_mat_a[0]); i++) */
  /*   ptr_a_addr[i] = stack_mat_a[i]; */
  /* for(int i=0; i<sizeof(stack_mat_b)/sizeof(stack_mat_b[0]); i++) */
  /*   ptr_b_addr[i] = stack_mat_b[i]; */
  memcpy((void*)ptr_a_addr, &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)ptr_b_addr, &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)ptr_c_addr, 0, 4*4*sizeof(float));
  time1 = read_csr_safe(cycle);
  printf("Copy cycles: %d\n", time1-time0-ct);

  println("Buffering command arguments:");
  time0 = read_csr_safe(cycle);
  struct MatUnitArgs args[16];
  for(int i=0; i<16; i++) {
    uint8_t x = i % cw;
    uint8_t y = i / cw;
    args[i].unit = i%ACCEL_UNITS;
    args[i].count = count;
    args[i].ptr_a.addr = ptr_a_addr; args[i].ptr_a.offset = count*y; args[i].ptr_a.stride = 1;
    args[i].ptr_b.addr = ptr_b_addr; args[i].ptr_b.offset = x;       args[i].ptr_b.stride = cw;
    args[i].ptr_c.addr = ptr_c_addr+i;
  }
  time1 = read_csr_safe(cycle);
  printf("Buffer cycles: %d\n", time1-time0-ct);

  uint16_t busy_bits;
  time0 = read_csr_safe(cycle);
  for(int i=0; i<16; i++) {
    if(i%ACCEL_UNITS == 0) {
      do {
        busy_bits = *(uint16_t volatile*)ACCEL_BUSY_ADDR;
      } while(busy_bits & (1 << (i%ACCEL_UNITS)) > 0);
    }
    accel_load_command(args[i]);
    accel_exec_command();
  }
  while(busy_bits = *(uint16_t volatile*)ACCEL_BUSY_ADDR != 0);
  time1 = read_csr_safe(cycle);
  printf("Time taken: %d\n", time1-time0-ct);
  for(int i=0; i<16; i++)
    printf("Output: 0x%X -> %2.f\n", &ptr_c_addr[i], ptr_c_addr[i]);
}

void mat_test() {
  printf("Matrix Test!\n");
  uint32_t time0, time1;
  float stack_mat_c[4*4];
  memset((void*)stack_mat_c, 0, 4*4*sizeof(float));
  time0 = read_csr_safe(cycle);
  int i=0; int j=0;
  for(int i=0; i<4; i++) {
    for(int j=0; j<4; j++) {
      for(int k=0; k<64; k++) {
        stack_mat_c[i*4+j] += stack_mat_a[i*64+k] * stack_mat_b[k*4+j];
      }
    }
  }
  time1 = read_csr_safe(cycle);
  printf("Time taken: %d\n", time1-time0);

}

void main() {
  print("Hello, world!\n");
  mstatus_init();
  init_stack();

  uint32_t time0, time1;
  uint16_t busy_bits;
  float* ptr_a_addr = (float*)accel_malloc(sizeof(stack_mat_a)/sizeof(float));
  float* ptr_b_addr = (float*)accel_malloc(sizeof(stack_mat_b)/sizeof(float));
  float* ptr_c_addr = (float*)accel_malloc(4);

  time0 = read_csr_safe(cycle);
  /* for(int i=0; i<sizeof(stack_mat_a)/sizeof(stack_mat_a[0]); i++) */
  /*   ptr_a_addr[i] = stack_mat_a[i]; */
  /* for(int i=0; i<sizeof(stack_mat_b)/sizeof(stack_mat_b[0]); i++) */
  /*   ptr_b_addr[i] = stack_mat_b[i]; */
  memcpy((void*)ptr_a_addr, &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)ptr_b_addr, &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)ptr_c_addr, 0, 4*4*sizeof(float));
  time1 = read_csr_safe(cycle);
  printf("Copy cycles: %d\n", time1-time0);

  volatile struct MatUnitArgs_32B *cmd_region = (struct MatUnitArgs_32B*)ACCEL_HW_CMD_ADDR;
  println("Buffering command arguments:");
  time0 = read_csr_safe(cycle);
  struct MatUnitArgs_32B args;
  for(int i=0; i<16; i++) {
    uint8_t count = 64;
    uint8_t cw = 4;
    uint8_t x = i % cw;
    uint8_t y = i / cw;
    args.unit = i%ACCEL_UNITS;
    args.count = count;
    args.ptr_a.addr = ptr_a_addr; args.ptr_a.offset = count*y; args.ptr_a.stride = 1;
    args.ptr_b.addr = ptr_b_addr; args.ptr_b.offset = x;       args.ptr_b.stride = cw;
    args.ptr_c.addr = ptr_c_addr+i;
    cmd_region[i] = args;
  }
  memset(&cmd_region[16], 0, sizeof(struct MatUnitArgs_32B));
  time1 = read_csr_safe(cycle);
  printf("Buffer cycles: %d\n", time1-time0);

  time0 = read_csr_safe(cycle);
  accel_exec_command();
  while(busy_bits = *(uint16_t volatile*)ACCEL_BUSY_ADDR != 0);
  time1 = read_csr_safe(cycle);

  printf("Time taken: %d\n", time1-time0);
  for(int i=0; i<16; i++)
    printf("0x%X -> %2.f\n", &ptr_c_addr[i], ptr_c_addr[i]);
}
void irqCallback() {
}
