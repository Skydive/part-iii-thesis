#pragma once
/* FOR TESTBENCH!  */
/* register definitions */
#define REG_RBR		0x00 /* Receiver buffer reg. */
#define REG_THR		0x00 /* Transmitter holding reg. */
#define REG_LCR		0x0C /* Line control reg. */
#define REG_LSR		0x14

/* Line status */
#define LSR_DR			0x01 /* Data ready */
#define LSR_OE			0x02 /* Overrun error */
#define LSR_PE			0x04 /* Parity error */
#define LSR_FE			0x08 /* Framing error */
#define LSR_BI			0x10 /* Break interrupt */
#define LSR_THRE		0x20 /* Transmitter holding register empty */
#define LSR_TEMT		0x40 /* Transmitter empty */
#define LSR_EIRF		0x80 /* Error in RCVR FIFO */

/* FOR TESTBENCH!  */

