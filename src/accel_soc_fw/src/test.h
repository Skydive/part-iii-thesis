#pragma once
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include "printf.h"

#define TEST_CONTROL_ADDR 0xC0001000UL
#define TEST_DATA_ADDR 0xC0001008UL
#define TEST_RANGE 4


#define read_csr_safe(reg) ({ register long __tmp asm("a0");  \
      asm volatile ("csrr %0, " #reg : "=r"(__tmp));          \
      __tmp; })

void main_test() {
  volatile uintptr_t control_addr = TEST_CONTROL_ADDR;
  volatile uintptr_t data_addr = TEST_DATA_ADDR;

  uint32_t write_pre, write_post;
  for(int i=0; i<TEST_RANGE; i++) {
    write_pre = read_csr_safe(cycle);
    *((uint32_t*)data_addr+i) = i;
    write_post = read_csr_safe(cycle);
    uint32_t data = *((uint32_t*)data_addr+i);
    printf("%d: %d\n", i, data);
  }

  println("Set Control Bit..");
  *((uint8_t*)control_addr) |= 0x1;

  uint32_t csr_stall = read_csr_safe(cycle);
  uint32_t csr_stall2 = read_csr_safe(cycle);
  while(*((uint8_t*)control_addr) & 0x2 == 0) {}
  uint32_t csr_stall_end = read_csr_safe(cycle);
  
  println("Stalling..");

  println("Stall complete!");
  for(int i=0; i<TEST_RANGE; i++) {
    uint32_t data = *((uint32_t*)data_addr+i);
    printf("%d: %d\n", i, data);
  }

  printf("CSR cycles: %d\n", csr_stall2-csr_stall);
  printf("Stall cycles: %d\n", csr_stall_end-csr_stall);
  printf("Write cycles: %d\n", write_post-write_pre);
}

