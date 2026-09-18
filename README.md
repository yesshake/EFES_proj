# FPGA Audio Effects Processor

## Overview

This project is a real-time audio effects processor implemented on an Intel/Altera Cyclone V FPGA (Terasic DE1-SoC board).

Audio from a computer is fed into the DE1-SoC's LINE-IN jack. The board's WM8731 audio codec digitizes the signal, and the FPGA captures it over I2S, applies a chain of configurable effects, and transmits the processed audio over a second I2S link to an external MAX98357A amplifier driving a speaker.

Effects that are currently implemented: volume scaling, bit crushing, and downsampling. Each effect is controlled by a 4 bit parameter adjustable from the board's push buttons. STM32 microcontroller handles preset storage so that effect configurations can be saved and recalled.

## System Architecture

```
Computer audio output
        │
        ▼
  DE1-SoC LINE-IN
        │
        ▼
   WM8731 ADC
        │
        ▼
┌───────────────────────────────┐
│            FPGA               │
│                               │
│   I2S Receiver (i2s_rx)       │
│        │                      │
│        ▼                      │
│   Audio Effects               │    Push buttons
│   (sample_effects)  ◄─────────┼─── & switches
│        │                      │
│        ▼                      │
│   I2S Transmitter (i2s_tx)    │
│                               │
│   Settings ──── UART ─────────┼──► STM32 + EEPROM
│                               │
│   HEX displays / LEDs         │
└───────────────┬───────────────┘
                │
                ▼
          MAX98357A
                │
                ▼
            Speaker
```

The FPGA operates across two clock domains. A 50 MHz system clock drives codec configuration, user-interface logic, and UART communication. The WM8731 generates its own bit clock (~3 MHz) and word clock, which drive the I2S receive, effects processing, and I2S transmit paths.

## Audio Signal Path

The WM8731 codec is configured at power-up via I2C to operate in master mode with a 48 kHz sample rate, 16 bit samples, and standard I2S framing.

Once configured, the codec begins generating BCLK and LRCLK, and the FPGA captures 16 bit samples from the ADC serial data line.

After the effects chain, the processed sample is loaded into an I2S transmitter that serializes it into both the left and right output slots. The output I2S signals (BCLK, LRCLK, data) are routed to GPIO pins connected to the MAX98357A amplifier.

## Audio Effects

There are three effects in series on every sample:

**Volume** — Scales amplitude using a 4 bit gain setting (0–15). Levels 0–14 apply a gain of *N*/16. Level 15 passes the sample unchanged at full volume.

**Bit crush** — Reduces effective bit depth by zeroing a configurable number of LSBs, 0–15 bits cleared.

**Downsample** — Reduces the effective sample rate by holding the output sample constant. A setting of 0 updates every sample; a setting of *N* holds each output value for *N*+1 input samples.

## Preset Management

The project includes a preset system that allows effect configurations to be saved and restored. Each preset contains the three effect parameters (volume, crush, downsample) indexed by a 4 bit preset ID (0–15).

From the DE1-SoC, the user selects a preset slot and triggers a save or load operation through the board switches and buttons. The FPGA sends a request over UART (115 200 baud) to an external STM32L412 microcontroller. On a save, the MCU writes the effect settings to I2C EEPROM. On a load, it reads the stored values and returns them to the FPGA, which applies them as the active effect parameters.

The preset management firmware on the STM32 is implemented. Full integration and debugging of the FPGA<->MCU preset flow is currently ongoing.

## Hardware

| Component | Description |
|---|---|
| Terasic DE1-SoC | FPGA development board (Cyclone V 5CSEMA5F31C6) |
| WM8731 | On-board audio codec — ADC captures LINE-IN, I2S master mode |
| Computer | Audio source connected to the DE1-SoC 3.5 mm LINE-IN jack |
| MAX98357A | External I2S amplifier module driving the speaker |
| STM32L412 | External MCU handling preset storage over UART |
| I2C EEPROM | Connected to the STM32 for non-volatile preset storage |

The DE1-SoC buttons (KEY0–KEY2) adjust effect parameters and trigger save/load operations. Switches (SW[2:0]) select the control mode. Six 7-segment displays show the current volume, crush, and downsample values, and four LEDs indicate the selected preset index.

## Current Status

The FPGA audio processing path is functional: audio from the computer is captured through the DE1-SoC line input, processed by the configurable effects chain, and played through the external MAX98357A amplifier and speaker.

The preset-management firmware has been implemented on the STM32. Integration and debugging of the complete FPGA/software preset workflow are ongoing.

A simulation testbench (`tb_stage_1`) verifies the I2C codec configuration sequence, I2S receive/transmit, and mono audio pipeline.

## Demo
