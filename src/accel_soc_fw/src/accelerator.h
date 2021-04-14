#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "mem_map.h"
#include "libc.h"
#include "printf.h"

// Fake heap!
#define ACCEL_STAT_ADDR mkTEST_ADDR(0)
#define ACCEL_CMD_ADDR mkTEST_ADDR(32)
#define ACCEL_DATA_ADDR mkTEST_ADDR(64)

#define ACCEL_STAT_BUSY_BIT 0
#define ACCEL_STAT_EXEC_BIT 1

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

struct MatUnitArgs {
  uint16_t count;
  struct MatUnitPtr ptr_a;
  struct MatUnitPtr ptr_b;
  struct MatUnitPtr ptr_c;
} __attribute__((packed));

// Status Query
bool accel_exec_is_busy() {
  volatile uint8_t* p = (uint8_t*)ACCEL_STAT_ADDR;
  return (bool)(*p & (1 << 1) > 0);
}
void accel_exec_command() {
  volatile uint8_t* p = (uint8_t*)ACCEL_STAT_ADDR;
  *p = *p | (1<<0);
}

/* uint16_t swe_u16(uint16_t s) { */
/*   printf("TEST"); */
/*   uint32_t result; */
/*   uint8_t* p = (uint8_t*)result; */
/*   uint8_t* q = (uint8_t*)&s; */
/*   p[0] = q[1]; */
/*   p[1] = q[0]; */
/*   return result; */
/* } */
/* uint32_t swe_u32(uint32_t s) { */
/*   uint32_t result; */
/*   uint8_t* p = (uint8_t*)result; */
/*   uint8_t* q = (uint8_t*)&s; */
/*   p[0] = q[3]; */
/*   p[1] = q[2]; */
/*   p[2] = q[1]; */
/*   p[3] = q[0]; */
/*   return result; */
/* } */


void accel_load_command(struct MatUnitArgs args) {
  printf("Fuck: %d\n", sizeof(struct MatUnitArgs));
  memcpy((void*)ACCEL_CMD_ADDR, &args, sizeof(struct MatUnitArgs));
}

void accel_exec_command_sync() {
  accel_exec_command();
  while(accel_exec_is_busy());
}


