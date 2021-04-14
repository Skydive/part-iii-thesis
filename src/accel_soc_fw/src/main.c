#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include "libc.h"
#include "accelerator.h"
#include "printf.h"

#define ACCEL_RANGE 4
#define FREEZE_LPS 10

extern char _stack_size;

#define MSTATUS_FS          0x00006000
#define write_csr(reg, val) ({                            \
      asm volatile ("csrw " #reg ", %0" :: "rK"(val)); })

void mstatus_init() {
  uintptr_t mstatus = 0;
  mstatus |= MSTATUS_FS;

  write_csr(mstatus, mstatus);
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
  mstatus_init();

  char buffer[32];
  printf("UART Controller Float!\n");

  /* float a = 1.0f; */
  /* float b = 5.5f; */

  /* println("UART Controller Test!\n"); */

  /* ftoa(a+b, buffer, 4); */
  /* print("A: "); print(buffer); print("\n"); */

  /* println("I AM SLOW!"); */
  /* println("PLS SPEED ME UP! TEST"); */

  printf("Hello, world!");

  volatile uintptr_t ptr_a_addr = accel_malloc(4);
  uintptr_t ptr_b_addr = accel_malloc(4);
  uintptr_t ptr_c_addr = accel_malloc(4);


  struct MatUnitArgs args = {
    .count = (2),
    .ptr_a = {.addr = (ptr_a_addr), .offset = 0, .stride = 1},
    .ptr_b = {.addr = (ptr_b_addr), .offset = 0, .stride = 2},
    .ptr_c = {.addr = (ptr_c_addr), .offset = 0, .stride = 1},
  };
  memcpy((void*)(args.ptr_a.addr), &stack_mat_a, sizeof(stack_mat_a));
  memcpy((void*)(args.ptr_b.addr), &stack_mat_b, sizeof(stack_mat_b));
  memset((void*)(args.ptr_c.addr), 0, 2*2*sizeof(float));

  printf("ptr_a_addr: 0x%X\n", ptr_a_addr);



  accel_load_command(args);
  /* printf("Verifying Accelerator Memory Range?\n"); */
  /* for(int i=0; i<8; i++) { */
  /*   int32_t* p = (int32_t*)ACCEL_CMD_ADDR; */
  /*   printf("0x%X: %d\n", p+i, p[i]); */
  /* } */
  /* /\* for(int i=0; i<8; i++) { *\/ */
  /*   uint32_t* p = (uint32_t*)ACCEL_CMD_ADDR; */
  /*   for(int j=0; j<4; j++) */
  /*     printf("%X ", (p[i] & (1 << 8*j) >> 8*j)); */
  /*   printf("\n"); */
  /* } */

  accel_exec_command_sync();
  printf("Done!");
  printf("Output: 0x%X -> %2.f", ptr_c_addr, *(float*)ptr_c_addr);
  return 0;
  /* volatile uintptr_t control_addr = TEST_CONTROL_ADDR; */
  /* volatile uintptr_t data_addr = TEST_DATA_ADDR; */

  /* println("Writing data to peripheral:"); */
  /* for(int i=0; i<ACCEL_RANGE; i++) { */
  /*   *((uint32_t*)data_addr+i) = i; */
  /* } */

  /* for(int i=0; i<ACCEL_RANGE; i++) { */
  /*   uint32_t big = *((uint32_t*)data_addr+i); */
  /*   itoa(big, buffer, sizeof(buffer), 10); */
  /*   print("Read A: "); print(buffer); print("\n"); */
  /* } */


  /* println("Set Control Bit.."); */
  /* *((uint8_t*)control_addr) |= 0x1; */

  /* println("Stalling.."); */
  /* while(*((uint8_t*)control_addr) & 0x2 == 0) {} */

  /* println("Stall complete!"); */
  /* for(int i=0; i<ACCEL_RANGE; i++) { */
  /*   uint32_t big = *((uint32_t*)data_addr+i); */
  /*   itoa(big, buffer, sizeof(buffer), 10); */
  /*   print("Read A: "); print(buffer); print("\n"); */
  /* } */

  print_slow("SPEED ME UP PLEASE I BEG YOU\n");
  const int nloops = FREEZE_LPS;
  memset(buffer, '\0', sizeof(buffer));
  for(int i=0; i<sizeof(buffer)/sizeof(buffer[0]); i++)
    buffer[i] = '\0';

  for(int i=0; i<10; i++) {
    print("LOOP: ");
    buffer[0] = i +'0';
    print(buffer);
    print("\n");
    delay(nloops);
  }
  println("BYE BYE!");
}

void irqCallback() {
}
