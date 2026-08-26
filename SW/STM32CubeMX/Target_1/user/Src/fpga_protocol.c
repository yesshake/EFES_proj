#include "fpga_protocol.h"
#include "uart.h"

#include <stddef.h>

FPGA_ProtocolStatus_t FPGA_receive_request(FPGA_Request_t *request, uint32_t timeout_ms){
    UART_Status_t uart_status;
    uint8_t command;
    uint8_t data[4];
    // Read command type -> fill request field

    if (request == NULL)
    {
        return FPGA_PROTOCOL_ERROR;
    }

    uart_status = UART_read_byte(&command, timeout_ms);

    if (uart_status == UART_TIMEOUT){
        return FPGA_PROTOCOL_TIMEOUT;
    }

    if (uart_status != UART_OK){
        return FPGA_PROTOCOL_ERROR;
    }

    if (command == FPGA_CMD_SAVE_PRESET){
        // Receive: preset_id, volume, bit_depth, downsample
        if (UART_read(data, 4U, timeout_ms) != UART_OK){
            return FPGA_PROTOCOL_ERROR;
        }

        request->type                = FPGA_REQUEST_SAVE;
        request->preset_id           = data[0];
        request->settings.volume     = data[1];
        request->settings.bit_depth  = data[2];
        request->settings.downsample = data[3];

        return FPGA_PROTOCOL_OK;
    }

    if (command == FPGA_CMD_LOAD_PRESET){
        if (UART_read_byte(&request->preset_id, timeout_ms) != UART_OK)
        {
            return FPGA_PROTOCOL_ERROR;
        }
        request->type = FPGA_REQUEST_LOAD;
        return FPGA_PROTOCOL_OK;
    }

    return FPGA_PROTOCOL_ERROR;
}

FPGA_ProtocolStatus_t FPGA_send_preset(uint8_t preset_id, const FPGA_Settings_t *settings, uint32_t timeout_ms){
    uint8_t frame[5];

    if (settings == NULL){
        return FPGA_PROTOCOL_ERROR;
    }

    frame[0] = FPGA_CMD_PRESET_DATA;
    frame[1] = preset_id;
    frame[2] = settings->volume;
    frame[3] = settings->bit_depth;
    frame[4] = settings->downsample;

    if (UART_write(frame, sizeof(frame), timeout_ms) != UART_OK)
    {
        return FPGA_PROTOCOL_ERROR;
    }

    return FPGA_PROTOCOL_OK;
}