#include "i2c.h"
#include "platform_time.h"
#include "stm32f3xx.h"

static int I2C_timeout_expired(uint32_t start_time, uint32_t timeout_ms){
    return ((uint32_t)(Platform_time_ms() - start_time) >= timeout_ms);
}

static I2C_Status_t I2C_check_errors(void)
{
    uint32_t status = I2C1->ISR;

    if ((status & I2C_ISR_NACKF) != 0U)
    {
        I2C1->ICR = I2C_ICR_NACKCF;
        return I2C_NACK;
    }

    if ((status & I2C_ISR_BERR) != 0U)
    {
        I2C1->ICR = I2C_ICR_BERRCF;
        return I2C_BUS_ERROR;
    }

    if ((status & I2C_ISR_ARLO) != 0U)
    {
        I2C1->ICR = I2C_ICR_ARLOCF;
        return I2C_ARBITRATION_LOST;
    }

    if ((status & I2C_ISR_OVR) != 0U)
    {
        I2C1->ICR = I2C_ICR_OVRCF;
        return I2C_OVERRUN;
    }

    return I2C_OK;
}



#define I2C_TIMING_8MHZ_100KHZ  0x10420F13U

void I2C_init(void)
{
    // Enable the GPIOB and I2C1 peripheral clock
    RCC->AHBENR |= RCC_AHBENR_GPIOBEN;
    RCC->APB1ENR |= RCC_APB1ENR_I2C1EN;

    // Select HSI 8 MHz as the I2C1  clock  with I2C1SW = 0
    RCC->CFGR3 &= ~RCC_CFGR3_I2C1SW;

    // Reset I2C1
    RCC->APB1RSTR |= RCC_APB1RSTR_I2C1RST;
    RCC->APB1RSTR &= ~RCC_APB1RSTR_I2C1RST;

    // Configure PB6 and PB7 in alternate function mode: MODER binary 10.
    GPIOB->MODER &= ~((3U << (6U * 2U)) | (3U << (7U * 2U)));
    GPIOB->MODER |=  ((2U << (6U * 2U)) | (2U << (7U * 2U)));

    // I2C output mode must be open drain
    GPIOB->OTYPER |= (1U << 6U) | (1U << 7U); 

    // Select high GPIO output speed
    GPIOB->OSPEEDR &= ~((3U << (6U * 2U)) | (3U << (7U * 2U)));
    GPIOB->OSPEEDR |=  ((2U << (6U * 2U)) | (2U << (7U * 2U))); // 10

    // No internal pull resistors. The I2C bus uses external pull-up resistors from the eeprom module
    GPIOB->PUPDR &= ~((3U << 12U) | (3U << 14U));

    // Select alternative function AF4 for the pins PB6 (I2C1_SCL), and PB7(I2C1_SDA) in AFR[0]
    GPIOB->AFR[0] &= ~((0xFU << (6U * 4U)) | (0xFU << (7U * 4U)));
    GPIOB->AFR[0] |=  ((4U << (6U * 4U)) | (4U << (7U * 4U)));

    // I2C must be disabled before TIMINGR is modified
    I2C1->CR1 &= ~I2C_CR1_PE;

    // Analog filter enabled, digital filter disabled, interrupts and DMA disabled
    I2C1->CR1 = 0U;

    // 100 kHz I2C using an 8 MHz I2C kernel clock
    I2C1->TIMINGR = I2C_TIMING_8MHZ_100KHZ;

    // Clear status flags
    I2C1->ICR = I2C_ICR_ADDRCF |
                I2C_ICR_NACKCF |
                I2C_ICR_STOPCF |
                I2C_ICR_BERRCF |
                I2C_ICR_ARLOCF |
                I2C_ICR_OVRCF  |
                I2C_ICR_TIMOUTCF;

    // Enable I2C1
    I2C1->CR1 |= I2C_CR1_PE;
}


I2C_Status_t I2C_write(uint8_t address, const uint8_t *data, size_t length, uint32_t timeout_ms)
{
    uint32_t start_time;
    I2C_Status_t status;
    size_t index;

    if ((address > 0x7FU) || (data == NULL) || (length == 0U) || (length > 255U)){
        return I2C_INVALID_ARGUMENT;
    }

    start_time = Platform_time_ms();

    // wait until no transaction is active on the bus
    while ((I2C1->ISR & I2C_ISR_BUSY) != 0U){
        if (I2C_timeout_expired(start_time, timeout_ms)){
            return I2C_BUSY;
        }
    }

    // Clear flags left by an earlier transaction 
    I2C1->ICR = I2C_ICR_NACKCF | I2C_ICR_STOPCF | I2C_ICR_BERRCF | I2C_ICR_ARLOCF | I2C_ICR_OVRCF;

    /*
     * Prepare CR2 for a 7 bit master write transaction
     *  SADD:    slave address, shifted into bits [7:1]
     *  RD_WRN:  0 = write
     *  NBYTES:  number of bytes
     *  AUTOEND: hardware generates STOP after the last byte
     */
    I2C1->CR2 = ((uint32_t)address << 1U) | ((uint32_t)length << I2C_CR2_NBYTES_Pos) | I2C_CR2_AUTOEND;

    // Generate START and transmit the slave address
    I2C1->CR2 |= I2C_CR2_START;

    for (index = 0U; index < length; ++index)
    {
        /*
         * wait for
         * - the address/previous byte was acknowledged;
         * - TXDR is ready for the next byte.
         * by checking isr with TXIS 
         */
        while ((I2C1->ISR & I2C_ISR_TXIS) == 0U)
        {
            status = I2C_check_errors();

            if (status != I2C_OK)
            {
                return status;
            }

            if (I2C_timeout_expired(start_time, timeout_ms))
            {
                I2C1->CR2 |= I2C_CR2_STOP;
                return I2C_TIMEOUT;
            }
        }

        I2C1->TXDR = data[index];
    }

    // AUTOEND generates STOP after NBYTES bytes STOPF confirms that the transaction ended
    while ((I2C1->ISR & I2C_ISR_STOPF) == 0U)
    {
        status = I2C_check_errors();

        if (status != I2C_OK)
        {
            return status;
        }

        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            I2C1->CR2 |= I2C_CR2_STOP;
            return I2C_TIMEOUT;
        }
    }

    // Clear STOPF by writing STOPCF in ICR
    I2C1->ICR = I2C_ICR_STOPCF;

    return I2C_OK;
}


I2C_Status_t I2C_read(uint8_t address, uint8_t *data, size_t length, uint32_t timeout_ms)
{
    uint32_t start_time;
    I2C_Status_t status;
    size_t index;

    if ((address > 0x7FU) ||
        (data == NULL) ||
        (length == 0U) ||
        (length > 255U))
    {
        return I2C_INVALID_ARGUMENT;
    }

    start_time = Platform_time_ms();

    // Wait until the bus is available
    while ((I2C1->ISR & I2C_ISR_BUSY) != 0U)
    {
        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            return I2C_BUSY;
        }
    }

    /* Clear flags remaining from an earlier transaction. */
    I2C1->ICR = I2C_ICR_NACKCF | I2C_ICR_STOPCF | I2C_ICR_BERRCF | I2C_ICR_ARLOCF | I2C_ICR_OVRCF;

    /*
     * Configure a 7 bit master read transaction:
     *  SADD:    slave address in bits [7:1]
     *  RD_WRN:  read direction
     *  NBYTES:  number of bytes to receive
     *  AUTOEND: automatically generate STOP
     */
    I2C1->CR2 =
        ((uint32_t)address << 1U) | ((uint32_t)length << I2C_CR2_NBYTES_Pos) | I2C_CR2_RD_WRN | I2C_CR2_AUTOEND;

    // Generate START and transmit address + read bit
    I2C1->CR2 |= I2C_CR2_START;

    for (index = 0U; index < length; ++index)
    {
        // Wait until one received byte is available in RXDR
        while ((I2C1->ISR & I2C_ISR_RXNE) == 0U)
        {
            status = I2C_check_errors();

            if (status != I2C_OK)
            {
                return status;
            }

            if (I2C_timeout_expired(start_time, timeout_ms))
            {
                I2C1->CR2 |= I2C_CR2_STOP;
                return I2C_TIMEOUT;
            }
        }

        data[index] = (uint8_t)I2C1->RXDR;
    }

    // AUTOEND should generate STOP after the final byte
    while ((I2C1->ISR & I2C_ISR_STOPF) == 0U)
    {
        status = I2C_check_errors();
        if (status != I2C_OK)
        {
            return status;
        }

        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            I2C1->CR2 |= I2C_CR2_STOP;
            return I2C_TIMEOUT;
        }
    }

    I2C1->ICR = I2C_ICR_STOPCF;

    return I2C_OK;
}

I2C_Status_t I2C_write_read(uint8_t address, const uint8_t *write_data, size_t write_length, uint8_t *read_data, size_t read_length, uint32_t timeout_ms)
{
    uint32_t start_time;
    I2C_Status_t status;
    size_t index;

    if ((address > 0x7FU)       ||
        (write_data == NULL)    ||
        (read_data == NULL)     ||
        (write_length == 0U)    ||
        (read_length == 0U)     ||
        (write_length > 255U)   ||
        (read_length > 255U))
    {
        return I2C_INVALID_ARGUMENT;
    }

    start_time = Platform_time_ms();

    while ((I2C1->ISR & I2C_ISR_BUSY) != 0U)
    {
        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            return I2C_BUSY;
        }
    }
    // clear status flags
    I2C1->ICR = I2C_ICR_NACKCF | I2C_ICR_STOPCF | I2C_ICR_BERRCF | I2C_ICR_ARLOCF | I2C_ICR_OVRCF;

    // First phase: write without AUTOEND The hardware will wait at TC instead of generating STOP
    I2C1->CR2 = ((uint32_t)address << 1U) | ((uint32_t)write_length << I2C_CR2_NBYTES_Pos);
    I2C1->CR2 |= I2C_CR2_START;

    for (index = 0U; index < write_length; ++index)
    {
        while ((I2C1->ISR & I2C_ISR_TXIS) == 0U)
        {
            status = I2C_check_errors();

            if (status != I2C_OK)
            {
                return status;
            }

            if (I2C_timeout_expired(start_time, timeout_ms))
            {
                I2C1->CR2 |= I2C_CR2_STOP;
                return I2C_TIMEOUT;
            }
        }

        I2C1->TXDR = write_data[index];
    }

    // TC means the write phase completed without generating STOP
    while ((I2C1->ISR & I2C_ISR_TC) == 0U)
    {
        status = I2C_check_errors();
        if (status != I2C_OK)
        {
            return status;
        }

        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            I2C1->CR2 |= I2C_CR2_STOP;
            return I2C_TIMEOUT;
        }
    }

    // Second phase: switch to read and generate a repeated START. AUTOEND generates STOP after the last received byte.
    I2C1->CR2 = ((uint32_t)address << 1U) | ((uint32_t)read_length << I2C_CR2_NBYTES_Pos) | I2C_CR2_RD_WRN | I2C_CR2_AUTOEND | I2C_CR2_START;

    for (index = 0U; index < read_length; ++index)
    {
        while ((I2C1->ISR & I2C_ISR_RXNE) == 0U)
        {
            status = I2C_check_errors();

            if (status != I2C_OK)
            {
                return status;
            }

            if (I2C_timeout_expired(start_time, timeout_ms))
            {
                I2C1->CR2 |= I2C_CR2_STOP;
                return I2C_TIMEOUT;
            }
        }

        read_data[index] = (uint8_t)I2C1->RXDR;
    }
    // wait for AUTOEND
    while ((I2C1->ISR & I2C_ISR_STOPF) == 0U)
    {
        status = I2C_check_errors();

        if (status != I2C_OK)
        {
            return status;
        }

        if (I2C_timeout_expired(start_time, timeout_ms))
        {
            I2C1->CR2 |= I2C_CR2_STOP;
            return I2C_TIMEOUT;
        }
    }
    
    I2C1->ICR = I2C_ICR_STOPCF;

    return I2C_OK;
}