#pragma once
/* register definitions */
#define REG_RBR 0x00 /* Recv data FIFO */
#define REG_THR 0x04 /* Trans data FIFO */
#define REG_LSR 0x08 /* Line status reg. */
#define REG_LCR 0x0C /* Line control reg. */

/* Line status */
#define LSR_DR			0x00 /* Data ready */
#define LSR_DF			0x01 /* Data full */
#define LSR_THRE		0x02 /* Transmitter holding register empty */
#define LSR_THRF		0x03 /* Transmitter holding register full */

#define LSR_OE			0x05 /* Overrun error */
#define LSR_FE			0x06 /* Framing error */
#define LSR_PE			0x07 /* Parity error */
