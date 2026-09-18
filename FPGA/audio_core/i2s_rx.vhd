-- I2S receiver — captures 16-bit samples from the WM8731.
--
-- WM8731 is I2S master (generates BCLK and LRCLK).
-- Data sampled on rising BCLK. Standard I2S one-bit delay.
-- Slots wider than 16 bits are ignored.

library ieee;
use ieee.std_logic_1164.all;

use work.efes_pkg.all;

entity i2s_rx is
  port (
    bclk       : in  std_logic;
    lrclk      : in  std_logic;
    adc_dat    : in  std_logic;
    sample_out : out audio_sample_t;
    valid      : out std_logic
  );
end entity i2s_rx;


architecture rtl of i2s_rx is

  type state_t is (
    SYNC_LRCLK,
    WAIT_LRCLK_EDGE,
    WAIT_MSB,
    RECEIVE_BITS
  );

  signal state : state_t := SYNC_LRCLK;

  signal previous_lrclk : std_logic := '0';

  signal shift_reg :
    audio_sample_t := (others => '0');

  signal sample_reg :
    audio_sample_t := (others => '0');

  signal bit_index :
    natural range 0 to AUDIO_SAMPLE_WIDTH-1 := AUDIO_SAMPLE_WIDTH-1;

  signal valid_reg : std_logic := '0';

begin

  sample_out <= sample_reg;
  valid      <= valid_reg;


  process (bclk)
  begin
    if rising_edge(bclk) then

      -- one-cycle pulse
      valid_reg <= '0';

      case state is

        -- latch initial LRCLK level
        when SYNC_LRCLK =>
          previous_lrclk <= lrclk;
          state          <= WAIT_LRCLK_EDGE;


        -- wait for a slot boundary
        when WAIT_LRCLK_EDGE =>
          if lrclk /= previous_lrclk then
            previous_lrclk <= lrclk;
            bit_index      <= AUDIO_SAMPLE_WIDTH-1;
            state          <= WAIT_MSB;
          end if;


        -- I2S has one BCLK delay between LRCLK edge and first data bit
        when WAIT_MSB =>
          shift_reg(AUDIO_SAMPLE_WIDTH-1) <= adc_dat;
          bit_index     <= AUDIO_SAMPLE_WIDTH-2;
          state         <= RECEIVE_BITS;


        when RECEIVE_BITS =>
          shift_reg(bit_index) <= adc_dat;

          if bit_index = 0 then

            -- grab adc_dat directly; shift_reg(0) hasn't updated yet
            sample_reg <= shift_reg(AUDIO_SAMPLE_WIDTH-1 downto 1) & adc_dat;
            valid_reg  <= '1';

            state <= WAIT_LRCLK_EDGE;

          else
            bit_index <= bit_index - 1;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;