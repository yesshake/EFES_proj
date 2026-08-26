#include <stdbool.h>

#include "uart.h"
#include "platform_time.h"
#include "stm32f3xx.h"

static bool UART_timeout_expired(uint32_t start_time, uint32_t timeout_ms){
    return (uint32_t)(Platform_time_ms() - start_time) >= timeout_ms;
}

static UART_Status_t UART_check_receive_errors(void)
{
    uint32_t isr;
    uint32_t clear_mask;
    UART_Status_t status;

    isr        = USART2->ISR;
    clear_mask = 0U;
    status     = UART_OK;

    //  
    if ((isr & USART_ISR_ORE) != 0U)
    {
        clear_mask |= USART_ICR_ORECF;
        status = UART_OVERRUN_ERROR;
    }

    if ((isr & USART_ISR_FE) != 0U)
    {
        clear_mask |= USART_ICR_FECF;

        if (status == UART_OK)
        {
            status = UART_FRAMING_ERROR;
        }
    }

    if ((isr & USART_ISR_NF) != 0U)
    {
        clear_mask |= USART_ICR_NCF;

        if (status == UART_OK)
        {
            status = UART_NOISE_ERROR;
        }
    }

    if (clear_mask != 0U) // if error happened
    {
        // clear the detected error
        USART2->ICR = clear_mask;

        // discard the potentially corrupted received byte
        USART2->RQR = USART_RQR_RXFRQ;
    }

    return status;
}

UART_Status_t UART_init(uint32_t peripheral_clock_hz, uint32_t baud_rate)
{
    uint32_t brr;

    if ((peripheral_clock_hz == 0U) || (baud_rate == 0U)){
        return UART_INVALID_ARGUMENT;
    }
    // Baud rate register
    brr = (peripheral_clock_hz + (baud_rate / 2U)) / baud_rate;

    // Enable GPIOA and USART2 clocks
    RCC->AHBENR  |= RCC_AHBENR_GPIOAEN;
    RCC->APB1ENR |= RCC_APB1ENR_USART2EN;

    // GPIO pins PA2 (bits 2*2 - 1 and 2*2) and PA15(bits 2*15 - 1 and 2*15): alternate function mode (binary 10) 
    GPIOA->MODER &= ~((3U << (2U * 2U)) | (3U << (15U * 2U))); // set bits to 00
    GPIOA->MODER |=  ((2U << (2U * 2U)) | (2U << (15U * 2U))); // set bits to 10

    // Select alternative function AF7 for the pins PA2 USART_TX in AFR[0], and PA15 USART_RX in AFR[1]
    GPIOA->AFR[0] &= ~(0xFU << (2U * 4U));
    GPIOA->AFR[0] |=  (7U   << (2U * 4U));

    GPIOA->AFR[1] &= ~(0xFU << ((15U - 8U) * 4U));
    GPIOA->AFR[1] |=  (7U   << ((15U - 8U) * 4U));

    // Push-pull output mode for PA2 and PA15
    GPIOA->OTYPER &= ~((1U << 2U) | (1U << 15U));

    // Pull up RX so that it remains high when undriven
    GPIOA->PUPDR &= ~((3U << (2U * 2U)) | (3U << (15U * 2U)));
    GPIOA->PUPDR |= (1U << (15U * 2U));

    // Disable and reset USART before modifying its configuration
    USART2->CR1 &= ~USART_CR1_UE;

    USART2->CR1 = 0U;
    USART2->CR2 = 0U;
    USART2->CR3 = 0U;

    // configure and enable to transmitter receiver by 
    //  - 16x oversampling (default on CR1=0)
    //  - 8 data bits (default on CR1=0)
    //  - no parity (default on CR1=0)
    //  - one stop bit (default on CR2=0) 
    // set BRR 
    USART2->BRR = brr;

    USART2->CR1 = USART_CR1_TE | USART_CR1_RE | USART_CR1_UE;

    return UART_OK;
}

UART_Status_t UART_write(const uint8_t *data, size_t length, uint32_t timeout_ms)
{
    uint32_t start_time;
    size_t index;

    if ((data == NULL) && (length != 0U)){
        return UART_INVALID_ARGUMENT;
    }

    if (length == 0U)
    {
        return UART_OK;
    }

    start_time = Platform_time_ms();

    for (index = 0U; index < length; ++index)
    {
        /*
         * TXE means that TDR can accept another byte.
         */
        while ((USART2->ISR & USART_ISR_TXE) == 0U)
        {
            if (UART_timeout_expired(start_time, timeout_ms))
            {
                return UART_TIMEOUT;
            }
        }

        USART2->TDR = data[index];
    }

    // TC means the final stop bit has physically left the UART
    while ((USART2->ISR & USART_ISR_TC) == 0U)
    {
        if (UART_timeout_expired(start_time, timeout_ms))
        {
            return UART_TIMEOUT;
        }
    }

    return UART_OK;
}

UART_Status_t UART_read(uint8_t *data, size_t length, uint32_t timeout_ms)
{
    UART_Status_t status;
    uint32_t start_time;
    size_t index;

    if ((data == NULL) && (length != 0U))
    {
        return UART_INVALID_ARGUMENT;
    }

    if (length == 0U){
        return UART_OK;
    }

    start_time = Platform_time_ms();

    for (index = 0U; index < length; ++index)
    {
        // busy wait until RDR contains an unread byte
        // return if error occurs
        while ((USART2->ISR & USART_ISR_RXNE) == 0U)
        {
            status = UART_check_receive_errors();

            if (status != UART_OK)
            {
                return status;
            }

            if (UART_timeout_expired(start_time, timeout_ms))
            {
                return UART_TIMEOUT;
            }
        }

        // check again for error before accepting the byte    
        status = UART_check_receive_errors();

        if (status != UART_OK)
        {
            return status;
        }
        data[index] = (uint8_t)USART2->RDR;
    }

    return UART_OK;
}