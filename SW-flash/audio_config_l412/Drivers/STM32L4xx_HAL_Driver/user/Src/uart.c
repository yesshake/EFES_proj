#include <stdbool.h>

#include "uart.h"
#include "platform_time.h"
#include "stm32l4xx.h"

static bool UART_timeout_expired(uint32_t start_time, uint32_t timeout_ms){
    return (uint32_t)(Platform_time_ms() - start_time) >= timeout_ms;
}

static UART_Status_t UART_check_receive_errors(void)
{
    uint32_t isr;
    uint32_t clear_mask;
    UART_Status_t status;

    isr        = USART1->ISR;
    clear_mask = 0U;
    status     = UART_OK;

    //  
    if ((isr & USART_ISR_ORE) != 0U){
        clear_mask |= USART_ICR_ORECF;
        status = UART_OVERRUN_ERROR;
    }

    if ((isr & USART_ISR_FE) != 0U){
        clear_mask |= USART_ICR_FECF;

        if (status == UART_OK){
            status = UART_FRAMING_ERROR;
        }
    }

    if ((isr & USART_ISR_NE) != 0U){
        clear_mask |= USART_ICR_NCF;

        if (status == UART_OK){
            status = UART_NOISE_ERROR;
        }
    }

    if (clear_mask != 0U){
        // clear the detected error
        USART1->ICR = clear_mask;
        // discard corrupted received byte
        USART1->RQR = USART_RQR_RXFRQ;
    }
    return status;
}

UART_Status_t UART_init(uint32_t peripheral_clock_hz, uint32_t baud_rate)
{
    uint32_t brr;

    if ((peripheral_clock_hz == 0U) || (baud_rate == 0U))
    {
        return UART_INVALID_ARGUMENT;
    }

    brr = (peripheral_clock_hz + (baud_rate / 2U)) / baud_rate;

    /* GPIOA clock */
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;

    /*
     * USART1 kernel clock = PCLK2
     * USART1SEL = 00
     */
    RCC->CCIPR &= ~RCC_CCIPR_USART1SEL;

    /* USART1 is on APB2 */
    RCC->APB2ENR |= RCC_APB2ENR_USART1EN;

    /* Reset USART1 */
    RCC->APB2RSTR |= RCC_APB2RSTR_USART1RST;
    RCC->APB2RSTR &= ~RCC_APB2RSTR_USART1RST;

    /*
     * PA9  -> USART1_TX
     * PA10 -> USART1_RX
     * AF7
     */

    GPIOA->MODER &= ~((3U << (9U * 2U)) | (3U << (10U * 2U)));
    GPIOA->MODER |= ((2U << (9U * 2U)) | (2U << (10U * 2U)));

    GPIOA->AFR[1] &= ~((0xFU << ((9U  - 8U) * 4U)) | (0xFU << ((10U - 8U) * 4U)));
    GPIOA->AFR[1] |= ((7U << ((9U  - 8U) * 4U)) | (7U << ((10U - 8U) * 4U)));

    /* Push-pull */
    GPIOA->OTYPER &= ~((1U << 9U) | (1U << 10U));

    /* TX no pull, RX pull-up */
    GPIOA->PUPDR &= ~((3U << (9U * 2U)) | (3U << (10U * 2U)));
    GPIOA->PUPDR |= (1U << (10U * 2U));

    /* Medium speed */
    GPIOA->OSPEEDR &= ~((3U << (9U * 2U)) | (3U << (10U * 2U)));
    GPIOA->OSPEEDR |= ((1U << (9U * 2U)) | (1U << (10U * 2U)));

    /* USART disabled/config reset */
    USART1->CR1 = 0U;
    USART1->CR2 = 0U;
    USART1->CR3 = 0U;

    USART1->BRR = brr;

    /* 8 data bits, no parity, 1 stop bit */
    USART1->CR1 = USART_CR1_TE | USART_CR1_RE | USART_CR1_UE;

    return UART_OK;
}

UART_Status_t UART_write(const uint8_t *data, size_t length, uint32_t timeout_ms)
{
    uint32_t start_time;
    size_t index;

    if ((data == NULL) && (length != 0U)){
        return UART_INVALID_ARGUMENT;
    }

    if (length == 0U){
        return UART_OK;
    }
    start_time = Platform_time_ms();

    for (index = 0U; index < length; ++index){
        /*
         * TXE means that TDR can accept another byte.
         */
        while ((USART1->ISR & USART_ISR_TXE) == 0U){
            if (UART_timeout_expired(start_time, timeout_ms)){
                return UART_TIMEOUT;
            }
        }
        USART1->TDR = data[index];
    }

    // TC means the final stop bit has physically left the UART
    while ((USART1->ISR & USART_ISR_TC) == 0U){
        if (UART_timeout_expired(start_time, timeout_ms)){
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

    if ((data == NULL) && (length != 0U)){
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
        while ((USART1->ISR & USART_ISR_RXNE) == 0U){
            status = UART_check_receive_errors();

            if (status != UART_OK){
                return status;
            }
            if (UART_timeout_expired(start_time, timeout_ms)){
                return UART_TIMEOUT;
            }
        }
        // check again for error before accepting the byte    
        status = UART_check_receive_errors();
        if (status != UART_OK){
            return status;
        }
        data[index] = (uint8_t)USART1->RDR;
    }
    return UART_OK;
}