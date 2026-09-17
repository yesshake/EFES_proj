#include "platform_time.h"
#include "stm32l4xx.h"

static volatile uint32_t system_time_ms = 0U;

void Platform_time_init(uint32_t core_clock_hz)
{
    if (core_clock_hz < 1000U){
        return;
    }

    /*
     * SysTick counts downward from LOAD to zero.
     * One interrupt every 1 ms:
     *
     * LOAD = (core_clock / 1000) - 1
     */
    SysTick->CTRL = 0U;
    SysTick->LOAD = (core_clock_hz / 1000U) - 1U;
    SysTick->VAL  = 0U;

    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
}

uint32_t Platform_time_ms(void)
{
    return system_time_ms;
}

void Platform_time_tick_isr(void)
{
    ++system_time_ms;
}