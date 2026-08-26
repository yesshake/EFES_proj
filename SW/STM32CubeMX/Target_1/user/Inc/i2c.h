#ifndef I2C_H
#define I2C_H

#include <stddef.h>
#include <stdint.h>

typedef enum
{
    I2C_OK,
    I2C_INVALID_ARGUMENT,
    I2C_TIMEOUT,
    I2C_BUSY,
    I2C_NACK,
    I2C_BUS_ERROR,
    I2C_ARBITRATION_LOST,
    I2C_OVERRUN
} I2C_Status_t;

void I2C_init(void);

I2C_Status_t I2C_write(uint8_t address, const uint8_t *data, size_t length, uint32_t timeout_ms);
I2C_Status_t I2C_read(uint8_t address, uint8_t *data, size_t length, uint32_t timeout_ms);
I2C_Status_t I2C_write_read(uint8_t address, const uint8_t *write_data,size_t write_length,uint8_t *read_data, size_t read_length, uint32_t timeout_ms);

#endif