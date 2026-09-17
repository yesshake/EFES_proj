#ifndef PLATFORM_TIME_H
#define PLATFORM_TIME_H

#include <stdint.h>

void Platform_time_init(uint32_t core_clock_hz);
uint32_t Platform_time_ms(void);
void Platform_time_tick_isr(void);

#endif