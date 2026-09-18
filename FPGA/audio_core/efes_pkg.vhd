-- Project wide shared types and width constants

library ieee;
use ieee.std_logic_1164.all;

package efes_pkg is

  -- 16 bit signed PCM audio sample
  constant AUDIO_SAMPLE_WIDTH : positive := 16;
  subtype audio_sample_t is std_logic_vector(AUDIO_SAMPLE_WIDTH-1 downto 0);

  -- 4 bit effect parameter (volume, crush, downsample)
  constant EFX_PARAM_WIDTH : positive := 4;
  subtype efx_param_t is std_logic_vector(EFX_PARAM_WIDTH-1 downto 0);

  -- preset slot index
  constant PRESET_ID_WIDTH : positive := 4;
  subtype preset_id_t is std_logic_vector(PRESET_ID_WIDTH-1 downto 0);

  -- UART byte
  constant UART_BYTE_WIDTH : positive := 8;
  subtype uart_byte_t is std_logic_vector(UART_BYTE_WIDTH-1 downto 0);

  -- 7 segment display output
  constant SEVEN_SEG_WIDTH : positive := 7;
  subtype seven_seg_t is std_logic_vector(SEVEN_SEG_WIDTH-1 downto 0);

end package efes_pkg;

package body efes_pkg is
end package body efes_pkg;
