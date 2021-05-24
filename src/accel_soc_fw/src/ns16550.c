#include <stdint.h>

#include "ns16550.h"
//#include "ns16550_tb.h"
#include "ns16550_xilinx_uartlite.h"



static uint8_t readb( uintptr_t addr )
{
	return *( (uint8_t *) addr );
}

static void writeb( uint8_t b, uintptr_t addr )
{
	*( (uint8_t *) addr ) = b;
}

void vOutNS16550( struct device_t *dev, unsigned char c )
{
	uintptr_t addr = dev->addr;

	while ( (readb( addr + REG_LSR ) & LSR_THRE) == 0 ) {
		/* busy wait */
	}

	writeb( c, addr + REG_THR );
}
