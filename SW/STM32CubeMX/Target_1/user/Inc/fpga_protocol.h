#ifndef FPGA_PROTOCOL_H
#define FPGA_PROTOCOL_H

#include <stdint.h>

#define FPGA_CMD_SAVE_PRESET  0x10U
#define FPGA_CMD_LOAD_PRESET  0x11U
#define FPGA_CMD_PRESET_DATA  0x12U

typedef struct
{
    uint8_t volume;
    uint8_t bit_depth;
    uint8_t downsample;
} FPGA_Settings_t;

typedef enum
{
    FPGA_REQUEST_SAVE,
    FPGA_REQUEST_LOAD
} FPGA_RequestType_t;

typedef struct
{
    FPGA_RequestType_t type;
    uint8_t preset_id;
    FPGA_Settings_t settings;
} FPGA_Request_t;

typedef enum
{
    FPGA_PROTOCOL_OK = 0,
    FPGA_PROTOCOL_TIMEOUT,
    FPGA_PROTOCOL_ERROR
} FPGA_ProtocolStatus_t;

FPGA_ProtocolStatus_t FPGA_receive_request(FPGA_Request_t *request, uint32_t timeout_ms);
FPGA_ProtocolStatus_t FPGA_send_preset(uint8_t preset_id, const FPGA_Settings_t *settings, uint32_t timeout_ms);

#endif  