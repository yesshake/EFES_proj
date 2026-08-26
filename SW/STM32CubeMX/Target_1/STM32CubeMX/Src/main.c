/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  ******************************************************************************
  */
/* Includes ------------------------------------------------------------------*/
#include "stm32f3xx.h"
#include "platform_time.h"
#include "uart.h"
#include "i2c.h"
#include "fpga_protocol.h"
#include "eeprom.h"
/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{
  FPGA_Request_t request;
  FPGA_Settings_t settings;
  
  // MCU Configuration
  Platform_time_init();
  UART_init();
  I2C_init();

  while (1){
      if (FPGA_receive_request(&request, 10U) != FPGA_OK) {
          continue;
      }
      switch (request.command){
          case FPGA_CMD_SAVE_SETTINGS:
              // The save request contains three settings sampled by the FPGA
              (void)EEPROM_save_preset(request.preset_id, &request.settings);
              break;
          case FPGA_CMD_LOAD_SETTINGS:
              if (EEPROM_load_preset(request.preset_id, &settings)){
                  (void)FPGA_send_preset(request.preset_id, &settings, 50U);
              }
              break;
          default:
              break;
    }
  }
}