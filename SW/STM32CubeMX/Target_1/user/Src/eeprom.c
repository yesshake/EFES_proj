#include "eeprom.h"
#include "i2c.h"

#include <stddef.h>

bool EEPROM_save_preset(uint8_t preset_id, const FPGA_Settings_t *settings){
    uint16_t address;
    uint8_t packet[5];
    uint32_t start;

    if (settings == NULL) {
        return false;
    }

    address = (uint16_t)preset_id * EEPROM_PRESET_SLOT_SIZE;

    packet[0] = (uint8_t)(address >> 8);
    packet[1] = (uint8_t)(address & 0xFFU);
    packet[2] = settings->volume;
    packet[3] = settings->bit_depth;
    packet[4] = settings->downsample;

    if (I2C_write(EEPROM_I2C_ADDRESS, packet, sizeof(packet), 50U) != I2C_OK) {
        return false;
    }

    // EEPROM internal programming time
    start = Platform_time_ms();
    while ((uint32_t)(Platform_time_ms() - start) < EEPROM_WRITE_TIME_MS);

    return true;
}

bool EEPROM_load_preset(uint8_t preset_id, FPGA_Settings_t *settings){
    uint16_t address;
    uint8_t address_bytes[2];
    uint8_t data[3];

    if (settings == NULL) {
        return false;
    }

    address = (uint16_t)preset_id * EEPROM_PRESET_SLOT_SIZE;

    address_bytes[0] = (uint8_t)(address >> 8);
    address_bytes[1] = (uint8_t)(address & 0xFFU);

    if (I2C_write_read(EEPROM_I2C_ADDRESS, address_bytes, sizeof(address_bytes), data, sizeof(data), 50U) != I2C_OK) {
        return false;
    }

    settings->volume     = data[0];
    settings->bit_depth  = data[1];
    settings->downsample = data[2];

    return true;
}