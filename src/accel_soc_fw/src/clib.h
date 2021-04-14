#include <stdint.h>

#include "ns16550.h"

#define NS16550_ADDR 0xC0000000UL

#define TEST_ADDR_BASE 0xC0001000UL
#define TEST_ADDR_STRIDE 4
#define mkTEST_ADDR(offset) TEST_ADDR_BASE + TEST_ADDR_STRIDE*offset
#define TEST_CONTROL_ADDR mkTEST_ADDR(0)
#define TEST_DATA_ADDR mkTEST_ADDR(2)


void _putchar(char c)
{
	struct device dev;
	dev.addr = NS16550_ADDR;
  vOutNS16550(&dev, c);
}


void itoa(int n, char* s, int len, int base)
{
  int i, sign;

  if ((sign = n) < 0)  /* record sign */
    n = -n;           /* make n positive */
  i = 0;
  do {  /* generate digits in reverse order */
    s[i++] = n % base + '0';  /* get next digit */
  } while ((n /= base) > 0);   /* delete it */
  if (sign < 0)
    s[i++] = '-';
  s[i] = '\0';

  for(int j=0; j<(i>>2 - 1); j++) {
    char tmp = s[j];
    s[j] = s[i-1-j];
    s[i-1-j] = tmp;
  }
}


int intToStr(int x, char str[], int d) 
{ 
  int i = 0; 
  while (x) { 
    str[i++] = (x % 10) + '0'; 
    x = x / 10; 
  } 
  
  // If number of digits required is more, then 
  // add 0s at the beginning 
  while (i < d) 
    str[i++] = '0'; 
  
  for(int j=0; j<(i>>2 - 1); j++) {
    char tmp = str[j];
    str[j] = str[i-1-j];
    str[i-1-j] = tmp;
  }

  str[i] = '\0'; 
  return i; 
} 

void ftoa(float n, char* res, int afterpoint)
{
  int ipart = (int)n;

  float fpart = n - (float)ipart;
  int i = intToStr(ipart, res, 0);

  if (afterpoint != 0) {
    res[i] = '.'; // add dot

    fpart = fpart * pow(10, afterpoint);

    intToStr((int)fpart, res + i + 1, afterpoint);
  }
}

void print(const char* str){
	struct device dev;
	dev.addr = NS16550_ADDR;
	while(*str){
		vOutNS16550(&dev, *str);
		str++;
	}
}


void println(const char* str){
	struct device dev;
	dev.addr = NS16550_ADDR;
	print(str);
	vOutNS16550( &dev, '\n' );
}

void delay(uint32_t loops){
	for(int i=0;i<loops;i++){
		asm volatile("nop");
	}
}
void print_slow(const char* str){
	struct device dev;
	dev.addr = NS16550_ADDR;
	while(*str){
		vOutNS16550(&dev, *str);
		//delay(1000UL);
		str++;
	}
}
