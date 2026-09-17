library ieee;
use ieee.std_logic_1164.all;

-- Source terasic demonstration of i2s sound and wm8731 datasheet

package wm8731_pkg is

  -- WM8731 control-interface address when CSB = 0 
  constant WM8731_I2C_ADDRESS : std_logic_vector(6 downto 0) := "0011010";

  -- Address byte transmitted for a write operation.
  constant WM8731_WRITE_BYTE : std_logic_vector(7 downto 0) := WM8731_I2C_ADDRESS & '0';

  -- Each entry contains:
  --   bits 15 downto 9 : 7 bit WM8731 register address
  --   bits  8 downto 0 : 9 bit register value
  type wm8731_config_array_t is array (natural range <>) of
    std_logic_vector(15 downto 0);

  constant WM8731_CONFIG_WORDS : wm8731_config_array_t := (
      x"1E00", -- R15: reset
      x"1200", -- R9 : interface inactive
  
      x"0017", -- R0 : Left line input, 0 dB, UNMUTED
      x"0217", -- R1 : Right line input, 0 dB, UNMUTED
  
      x"0800", -- R4 : select LINE-IN
      x"0A08", -- R5 : ADC HPF enabled, codec DAC muted
      x"0C5A", -- R6 : LINE-IN + ADC powered
      x"0E42", -- R7 : master, 16-bit, I2S
      x"1002", -- R8 : 48 kHz, normal mode, 384 fs
      x"1201"  -- R9 : interface active
  );

end package wm8731_pkg;

package body wm8731_pkg is
end package body wm8731_pkg;
