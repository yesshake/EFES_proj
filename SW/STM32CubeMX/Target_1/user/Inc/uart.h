#ifndef UART_H
#define UART_H

#include <stddef.h>
#include <stdint.h>

typedef enum
{
    UART_OK,
    UART_INVALID_ARGUMENT,
    UART_TIMEOUT,
    UART_OVERRUN_ERROR,
    UART_FRAMING_ERROR,
    UART_NOISE_ERROR
} UART_Status_t;

/*
 * peripheral_clock_hz is the clock supplied to USART2,
 * normally PCLK1.
 */
UART_Status_t UART_init( uint32_t peripheral_clock_hz, uint32_t baud_rate);
UART_Status_t UART_write(const uint8_t *data, size_t length, uint32_t timeout_ms);
UART_Status_t UART_read(uint8_t *data, size_t length, uint32_t timeout_ms);

#endif