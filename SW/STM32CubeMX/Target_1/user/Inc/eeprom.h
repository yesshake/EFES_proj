#ifndef EEPROM_H
#define EEPROM_H

#include <stdint.h>
#include "fpga_protocol.h"

#define EEPROM_I2C_ADDRESS       0x50U   /* Address pins low */
#define EEPROM_SIZE_BYTES        32768U
#define EEPROM_PAGE_SIZE         64U
#define EEPROM_WRITE_TIME_MS     10U
#define EEPROM_PRESET_SLOT_SIZE  4U

bool EEPROM_save_preset(uint8_t preset_id, const FPGA_Settings_t *settings);
bool EEPROM_load_preset(uint8_t preset_id, FPGA_Settings_t *settings);

#endif