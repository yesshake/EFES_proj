# Preset and Control Interface

This document describes how audio-effect settings are controlled on the FPGA and how presets are exchanged with the external STM32 microcontroller.

## Effect Settings

Three effect parameters and a preset index are managed by the `settings` module in the `clk_50m` domain. Each is a 4 bit value (0–15).

| Setting | Port Name | Description |
|---|---|---|
| Volume | `efx_vol` | Audio amplitude scaling (0 = silent) |
| Bit crush | `efx_crush` | Number of LSBs zeroed (0 = no effect) |
| Downsample | `efx_down` | Hold period (0 = no hold, *N* = hold for *N*+1 samples) |
| Preset ID | `preset_idx` | Index of the selected preset slot (0–15) |

### Local Control

Three debounced push buttons provide increment, decrement, and action functions. The switches (SW[2:0]) select which parameter the buttons affect:

| SW[2:0] | Mode |
|---|---|
| `000` | Adjust volume |
| `001` | Adjust bit crush |
| `010` | Adjust downsample |
| `011` | Adjust preset index |
| `100` | Action button triggers a **save** |
| `101` | Action button triggers a **load** |

### Display

Three `hex_display` instances show the current volume, crush, and downsample values as two digit decimal numbers on the DE1-SoC's 7-segment displays. Four LEDs show the selected preset index in binary.

## Preset Protocol

Presets are saved to and loaded from an I2C EEPROM attached to an STM32L412 microcontroller. The FPGA and MCU communicate over UART at 115200 baud, 8N1.

### UART Framing — `UART_setting_interface`

The `UART_setting_interface` module handles protocol framing on the FPGA side. It sits between the raw UART transmitter/receiver and the `settings` module.

Three command bytes identify the frame type:

| Command | Value | Direction | Meaning |
|---|---|---|---|
| `CMD_SAVE_PRESET` | `0x10` | FPGA → MCU | Save the following preset |
| `CMD_LOAD_PRESET` | `0x11` | FPGA → MCU | Load and return a preset |
| `CMD_PRESET_DATA` | `0x12` | MCU → FPGA | Preset data follows |

### Save Transaction

When the user triggers a save, the FPGA transmits a 5 byte frame:

```
Byte 0:  0x10  (CMD_SAVE_PRESET)
Byte 1:  preset_id       (4 bit value)
Byte 2:  volume           "
Byte 3:  crush            "
Byte 4:  downsample       "
```

The MCU receives this frame and writes the three effect values to EEPROM at the given preset index.

### Load Transaction

When the user triggers a load, the FPGA transmits a 2 byte request:

```
Byte 0:  0x11  (CMD_LOAD_PRESET)
Byte 1:  preset_id
```

The MCU looks up the preset in EEPROM and, if found, responds with a 5 byte frame:

```
Byte 0:  0x12  (CMD_PRESET_DATA)
Byte 1:  preset_id
Byte 2:  volume
Byte 3:  crush
Byte 4:  downsample
```

The `UART_setting_interface` module presents the three values to `settings`, which overwrites its local registers.

## MCU Firmware

The STM32L412 firmware (`SW-flash/audio_config_l412/`) runs a simple main loop:

1. Wait for a UART request from the FPGA.
2. If the request is a save (`FPGA_REQUEST_SAVE`), write the preset to EEPROM.
3. If the request is a load (`FPGA_REQUEST_LOAD`), read from EEPROM and send the preset data back over UART.

The firmware uses bare metal register level UART and I2C drivers alongside HAL-generated GPIO and clock initialization from STM32CubeMX.

## Current Status

| Component | Status |
|---|---|
| `settings` — local button/switch control | Functional |
| `hex_display` — 7-segment output | Functional |
| `UART_setting_interface` — protocol framing | Implemented |
| `uart_rx` / `uart_tx` — physical UART | Implemented |
| STM32 firmware — EEPROM save/load | Implemented |
| End-to-end FPGA ↔ MCU preset flow | Under debugging and validation |

The FPGA preset protocol logic and the MCU firmware have both been implemented. Integration and verifying: save and load operations with the FPGA and STM32 connected is currently being debugged.
