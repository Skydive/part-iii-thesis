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


const float stack_mat_a[] = {
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,

  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,

  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,

  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0,
};

const float stack_mat_b[] = {
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,

  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,

  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,

  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0,
  -2.0, -2.0, -2.0, -2.0
};


/* for(int i=0; i<16; i++) { */
/*   timea = read_csr_safe(cycle); */
/*   uint8_t x = i % cw; */
/*   uint8_t y = i / cw; */
/*   struct MatUnitArgs arg = { */
/*     .unit = i % 4, */
/*     .count = count, */
/*     .ptr_a = {.addr = ptr_a_addr, .offset = count*y, .stride = 1}, */
/*     .ptr_b = {.addr = ptr_b_addr, .offset = x, .stride = cw}, */
/*     .ptr_c = {.addr = ptr_c_addr+i, .offset = 0, .stride = 0}, */
/*   }; */
/* accel_load_command(arg); */
/* accel_exec_command_sync(); */

// Prediction: 2816
// Parallelism Result Buffer: 3001
// Parallelism Result unbuffered: 3312

void accel_test() {
  uint8_t count = 64;
  uint8_t cw = 4;
  uintptr_t ptr_a_addr = accel_malloc(sizeof(stack_mat_a)/sizeof(float));
  uintptr_t ptr_b_addr = accel_malloc(sizeof(stack_mat_b)/sizeof(float));
  float* ptr_c_addr = (float*)accel_malloc(4);
  memcpy((void*)ptr_a_addr, &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)ptr_b_addr, &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)ptr_c_addr, 0, 4*4*sizeof(float));

  uint32_t time0, time1, timea, timeb;

  /* struct MatUnitArgs args[16]; */
  /* for(int i=0; i<16; i++) { */
  /*   uint8_t x = i % cw; */
  /*   uint8_t y = i / cw; */
  /*   args[i].unit = i%4; */
  /*   args[i].count = count; */
  /*   args[i].ptr_a.addr = ptr_a_addr; args[i].ptr_a.offset = count*y; args[i].ptr_a.stride = 1; */
  /*   args[i].ptr_b.addr = ptr_b_addr; args[i].ptr_b.offset = x;       args[i].ptr_b.stride = cw; */
  /*   args[i].ptr_c.addr = ptr_c_addr+i; */
  /* } */

  /* time0 = read_csr_safe(cycle); */
  /* for(int i=0; i<16; i++) { */
  /*   uint8_t busy; */
  /*   if(i%4 == 0) while(busy = *(uint8_t*)ACCEL_BUSY_ADDR != 0){ delay(1); } */
  /*   accel_load_command(args[i]); */
  /*   accel_exec_command_sync(); */
  /* } */
  /* time1 = read_csr_safe(cycle); */


  time0 = read_csr_safe(cycle);
  for(int i=0; i<16; i++) {
    uint8_t x = i % cw;
    uint8_t y = i / cw;
    struct MatUnitArgs arg = {
      .unit = i % 4,
      .count = count,
      .ptr_a = {.addr = ptr_a_addr, .offset = count*y, .stride = 1},
      .ptr_b = {.addr = ptr_b_addr, .offset = x, .stride = cw},
      .ptr_c = {.addr = ptr_c_addr+i, .offset = 0, .stride = 0},
    };
    accel_load_command(arg);
    accel_exec_command_sync();
  }
  time1 = read_csr_safe(cycle);
  delay(100);

  for(int i=0; i<16; i++)
    printf("Output: 0x%X -> %2.f\n", &ptr_c_addr[i], ptr_c_addr[i]);
  printf("Time taken: %d\n", time1-time0-30);
}

void mat_test() {
  printf("Matrix Test!\n");
  float stack_mat_c[4*4];
  memset((void*)stack_mat_c, 0, 4*4*sizeof(float));
  uint32_t time0 = read_csr_safe(cycle);
  int i=0; int j=0;
  for(int i=0; i<4; i++) {
    for(int j=0; j<4; j++) {
      for(int k=0; k<64; k++) {
        stack_mat_c[i*4+j] += stack_mat_a[i*64+k] * stack_mat_b[k*4+j];
      }
    }
  }
  uint32_t time1 = read_csr_safe(cycle);
  for(int i=0; i<16; i++)
    printf("Output: 0x%X -> %2.f\n", &stack_mat_c[i], stack_mat_c[i]);
  printf("MATRIX: Time taken: %d\n", time1-time0-30);

}


void main() {
  printf("Hello, world!\n");
  mstatus_init();

  //main_test();

  /* println("I AM SLOW!"); */
  /* println("PLS SPEED ME UP! TEST"); */

  // Misalign addr
  //*((uint32_t*)0xC0001002UL) = 1337;


  /* uint8_t busy; */
  /* while(busy = *(uint8_t*)(ACCEL_BUSY_ADDR) != 0) { */
  /*   printf("BUSY: %h\n", busy); */
  /* } */

  accel_test();
  //mat_test();
  /* return 0; */
}

void irqCallback() {
}
