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
   4.0,  4.0,
   4.0,  4.0
};

const float stack_mat_b[] = {
  -2.0, -2.0,
   4.0,  4.0
};


void main() {
  printf("Hello, world!\n");
  mstatus_init();

  //main_test();

  /* println("I AM SLOW!"); */
  /* println("PLS SPEED ME UP! TEST"); */

  // Misalign addr
  //*((uint32_t*)0xC0001002UL) = 1337;
  
  uintptr_t ptr_a_addr = accel_malloc(4);
  uintptr_t ptr_b_addr = accel_malloc(4);
  uintptr_t ptr_c_addr = accel_malloc(4);
  struct MatUnitArgs args = {
    .count = 2,
    .ptr_a = {.addr = ptr_a_addr, .offset = 0, .stride = 1},
    .ptr_b = {.addr = ptr_b_addr, .offset = 0, .stride = 2},
    .ptr_c = {.addr = ptr_c_addr, .offset = 0, .stride = 1},
  };
  memcpy((void*)(args.ptr_a.addr), &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)(args.ptr_b.addr), &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)(args.ptr_c.addr), 0, 2*2*sizeof(float));


  for(int i=0; i<8; i++) {
    uint32_t* p = (uint32_t*)&args;
    printf("0x%X: ", p+i);
    for(int j=0; j<4; j++)
      printf("%.2X ", ((p[i] >> 8*j) & 0xFF));
    //printf("%d:%X ", j, (p[i] & (0xFF << 8*j) >> 8*j));
    printf("\n");
  }


  accel_load_command(args);
  printf("Verifying Accelerator Memory Range?\n");
  for(int i=0; i<8; i++) {
    uint32_t* p = (uint32_t*)ACCEL_CMD_ADDR;
    printf("0x%X: ", p+i);
    for(int j=0; j<4; j++)
      printf("%.2X ", ((p[i] >> 8*j) & 0xFF));
      //printf("%d:%X ", j, (p[i] & (0xFF << 8*j) >> 8*j));
    printf("\n");
  }
  /* accel_exec_command_sync(); */
  /* printf("Done!"); */
  /* printf("Output: 0x%X -> %2.f", ptr_c_addr, *(float*)ptr_c_addr); */
  /* return 0; */
}

void irqCallback() {
}
