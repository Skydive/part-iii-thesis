#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "mem_map.h"
#include "libc.h"
#include "printf.h"

// Fake heap!
#define ACCEL_STAT_ADDR mkACCEL_ADDR(0)
#define ACCEL_BUSY_ADDR mkACCEL_ADDR(1)
#define ACCEL_CMD_ADDR mkACCEL_ADDR(32)
#define ACCEL_DATA_ADDR mkACCEL_ADDR(64)

#define ACCEL_STAT_EXEC_BIT 0
#define ACCEL_STAT_BUSY_BIT 1

uintptr_t malloc_ptr = 0;
uintptr_t accel_malloc(int size) {
  uintptr_t offset = ACCEL_DATA_ADDR;
  volatile uintptr_t p = offset+malloc_ptr;
  malloc_ptr += size*sizeof(uintptr_t);
  return p;
}

void accel_reset() {
  malloc_ptr = 0;
}



// Command execution
struct MatUnitPtr {
  uintptr_t addr;
  uint8_t offset;
  uint8_t stride;
} __attribute__((packed));
void print_mat_unit_ptr(struct MatUnitPtr ptr) {
  printf("MatUnitPtr { addr: %X, offset: %d, stride: %d}", ptr.addr, ptr.offset, ptr.stride);
}
struct MatUnitArgs {
  uint8_t unit;
  uint8_t count;
  struct MatUnitPtr ptr_a;
  struct MatUnitPtr ptr_b;
  struct MatUnitPtr ptr_c;
} __attribute__((packed));
void print_mat_unit_args(struct MatUnitArgs args) {
  printf("MatUnitArgs { unit: %d, count: %d, ptr_a: ", args.unit, args.count); print_mat_unit_ptr(args.ptr_a);
  printf(", ptr_b: "); print_mat_unit_ptr(args.ptr_b);
  printf(", ptr_c: "); print_mat_unit_ptr(args.ptr_c);
  printf("}");
}

// Status Query
bool accel_exec_is_busy() {
  volatile uint8_t* p = (uint8_t*)ACCEL_STAT_ADDR;
  return (bool)(*p & (1 << 1) > 0);
}
void accel_exec_command() {
  volatile uint8_t* p = (uint8_t*)ACCEL_STAT_ADDR;
  *p = *p | (1<<0);
}

void accel_load_command(struct MatUnitArgs args) {
  volatile struct MatUnitArgs* base = (volatile struct MatUnitArgs*)ACCEL_CMD_ADDR;
  *base = args; // YAY C99 struct assignment!
  //printf("Size: %d\n", sizeof(struct MatUnitArgs));
  memcpy((void*)ACCEL_CMD_ADDR, &args, sizeof(struct MatUnitArgs));
}

void accel_exec_command_sync() {
  accel_exec_command();
  while(accel_exec_is_busy());
}


