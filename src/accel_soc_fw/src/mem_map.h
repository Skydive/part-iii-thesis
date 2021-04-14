#pragma once

#define TEST_ADDR_BASE 0xC0001000UL
#define TEST_ADDR_STRIDE 4
#define mkTEST_ADDR(offset) (TEST_ADDR_BASE + TEST_ADDR_STRIDE*offset)
#define TEST_CONTROL_ADDR mkTEST_ADDR(0)
#define TEST_DATA_ADDR mkTEST_ADDR(2)

// PRINTING
#define NS16550_ADDR 0xC0000000UL
