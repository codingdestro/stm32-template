#include <stm32f103x6.h>

int main(void) {
  RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
  GPIOC->CRH &= ~(0xF << 20);
  GPIOC->CRH |= (0x2 << 20);

  while (1) {
    GPIOC->ODR ^= GPIO_ODR_ODR13;
    for (volatile int i = 0; i < 800000; i++)
      ;
  }
}
