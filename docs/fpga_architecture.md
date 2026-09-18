# FPGA Architecture

This document describes the FPGA design in more detail than the main README. It covers module organization, data flow, clocking, and the audio processing pipeline.

The top-level entity is `sys_top`, defined in `top_level/sys_top.vhd`. It instantiates all sub-modules and manages the two clock domains.

## Top-Level Data Flow

```
                          clk_50m domain
                ┌──────────────────────────────────────┐
                │                                      │
                │  audio_pll ──► WM8731 master clock   │
                │                                      │
                │  i2c_master ──► WM8731 I2C config    │
                │                                      │
                │  debouncer ×3 ──► settings           │
                │                       │              │
                │               ┌───────┴───────┐      │
                │               │               │      │
                │          hex_display ×3   UART path  │
                │                               │      │
                └───────────────────────────────┼──────┘
                                                │
                     ┌─── CDC synchronizers ────┘
                     │
                ┌────▼──────────────────────────────────┐
                │           aud_bclk domain             │
                │                                       │
                │  i2s_rx ──► sample_effects ──► i2s_tx │
                │                                       │
                └───────────────────────────────────────┘
```

Effect parameters (volume, crush, downsample) are produced in the `clk_50m` domain by the `settings` module and crossed into the `aud_bclk` domain through dual-register synchronizers. These controls change slowly relative to the audio clock, so per-bit synchronization is sufficient.

## Audio Input

### PLL and Master Clock

An Intel FPGA PLL IP core (`audio_pll`) multiplies the 50 MHz board clock to produce an 18.432 MHz master clock (`aud_xck`). This clock is routed to the WM8731's XCK pin. The PLL's locked status is synchronized into `clk_50m` before the codec is configured.

### Codec Configuration — `i2c_master`

`i2c_master` performs a fixed I2C write sequence at startup, programming the WM8731 registers defined in `wm8731_pkg`. The controller waits for a configurable startup delay, then transmits each 16-bit register word as a three-byte I2C transaction (address byte + two data bytes). After all registers are written, the controller asserts a `done` signal.

The configuration establishes:

| Register | Setting |
|---|---|
| R0, R1 | Line input, 0 dB, unmuted |
| R4 | LINE-IN selected as ADC source |
| R5 | ADC high-pass filter enabled |
| R7 | Master mode, 16-bit word length, I2S format |
| R8 | 48 kHz sample rate, normal mode |
| R9 | Digital audio interface active |

The codec's on-board DAC output is muted (R5) since audio output goes through the external MAX98357A.

### I2S Receiver — `i2s_rx`

Once the WM8731 begins generating BCLK and LRCLK, `i2s_rx` captures incoming serial audio data.

The receiver operates entirely in the `aud_bclk` domain. It detects LRCLK transitions to identify slot boundaries, accounts for the standard I2S one-bit delay between the LRCLK edge and the first data bit, and shifts in 16 bits MSB-first. Extra bits beyond 16 (the I2S slot may be 32 bits wide) are ignored.

After each 16-bit sample is assembled, the receiver asserts a single-cycle `valid` pulse. The top level gates this pulse so that only the left-channel slot (LRCLK low) is retained — the system processes mono audio.

**Inputs:** `bclk`, `lrclk`, `adc_dat`
**Outputs:** `sample_out` (16-bit), `valid`

## Audio Processing — `sample_effects`

`sample_effects` applies three effects in series, clocked by `aud_bclk`. On each valid input sample:

1. **Volume scaling** — The 16-bit signed sample is multiplied by the 4-bit gain parameter. Levels 0–14 produce a gain of *N*/16 (signed multiply followed by a 4-bit arithmetic right shift). Level 15 bypasses the multiplier and passes the sample unchanged.

2. **Bit crushing** — The crush parameter specifies how many least-significant bits are forced to zero (0 = no effect, 15 = only the sign bit remains). The sign bit is never cleared.

3. **Downsampling** — A counter determines how often the output sample is updated. When the counter reaches zero, the current processed sample replaces the held output and the counter reloads to the downsample parameter value. Between updates, the output holds its previous value. A setting of 0 means every sample passes through; a setting of *N* holds each value for *N*+1 input periods.

The module pulses `valid_out` on every input sample regardless of the downsample hold, so downstream logic always knows when an input was processed.

**Inputs:** `sample_in`, `valid_in`, `efx_vol`, `efx_crush`, `efx_down`
**Outputs:** `sample_out`, `valid_out`

## Audio Output — `i2s_tx`

`i2s_tx` serializes the held mono sample into both I2S output slots. It uses a two-process architecture (registered + combinational) clocked on the *falling* edge of BCLK so that data transitions are stable well before the receiver's rising-edge sample point.

The transmitter detects LRCLK transitions to identify new slots. On each slot boundary it loads the current sample and begins shifting out bit 15 (MSB) first. After all 16 bits are transmitted, it pads the remainder of the slot with zeros if the external slot is wider than 16 bits.

The top level holds the transmitter's input at zero and its valid signal low until codec configuration is complete, keeping the amplifier output muted during startup.

**Inputs:** `bclk`, `lrclk`, `sample_in`, `valid_in`
**Output:** `dac_data` (serial)

## Settings and User Interface

### `debouncer`

A generic push-button debouncer with a configurable debounce time (default 20 ms at 50 MHz). Used for KEY0, KEY1, and KEY2.

### `settings`

Manages the four user-adjustable values: volume, crush, downsample, and preset index. Each is a 4-bit unsigned register (0–15). The module detects falling edges on the debounced button inputs and increments or decrements the selected register based on the current mode (determined by SW[2:0]).

When the MCU returns preset data, the module accepts new volume/crush/downsample values from the UART interface and overwrites the local registers.

Save and load strobes are generated when the user presses the action button in the corresponding switch mode.

### `hex_display`

Converts a 4-bit value to a pair of active-low 7-segment outputs showing the decimal representation (00–15). Three instances display the current volume, crush, and downsample values on HEX1:HEX0, HEX3:HEX2, and HEX5:HEX4 respectively.

## Clocking

| Clock | Source | Approximate Frequency | Domain |
|---|---|---|---|
| `clk_50m` | Board oscillator | 50 MHz | System logic, I2C, UART, settings |
| `aud_xck` | FPGA PLL | 18.432 MHz | WM8731 master clock (output only) |
| `aud_bclk` | WM8731 | ~3.072 MHz | I2S receive, effects, I2S transmit |

The two functional clock domains (`clk_50m` and `aud_bclk`) are declared as asynchronous clock groups in the SDC constraints. The PLL-generated clock is derived automatically by Quartus.

## Shared Type System — `efes_pkg`

Cross-module signal types are defined centrally in `efes_pkg` to avoid duplicated hard-coded widths:

| Subtype | Width | Purpose |
|---|---|---|
| `audio_sample_t` | 16 bits | I2S sample data throughout the pipeline |
| `efx_param_t` | 4 bits | Volume, crush, and downsample parameters |
| `preset_id_t` | 4 bits | Preset index |
| `uart_byte_t` | 8 bits | UART data bytes |
| `seven_seg_t` | 7 bits | 7-segment display outputs |

## RTL Source Organization

```
FPGA/
├── audio_core/
│   ├── efes_pkg.vhd           Shared types and width constants
│   ├── wm8731_pkg.vhd         WM8731 I2C register definitions
│   ├── i2c_master.vhd         Codec startup configuration (I2C)
│   ├── i2s_rx.vhd             I2S receiver
│   ├── i2s_tx.vhd             I2S transmitter
│   └── sample_effects.vhd     Effects processing chain
│
├── communication/
│   ├── uart_rx.vhd            UART receiver (115 200 baud)
│   ├── uart_tx.vhd            UART transmitter
│   └── UART_setting_interface.vhd   Preset protocol framing
│
├── ui_ctrl/
│   ├── debouncer.vhd          Push-button debouncer
│   ├── settings.vhd           Effect parameter registers
│   └── hex_display.vhd        Decimal 7-segment encoder
│
└── top_level/
    ├── sys_top.vhd            Main top-level entity
    ├── sys_top_smoke.vhd      Smoke-test wrapper (ties off UI)
    └── speaker_smoke.vhd      Direct ADC-to-amplifier bypass test
```
