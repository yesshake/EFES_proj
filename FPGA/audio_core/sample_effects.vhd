library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.efes_pkg.all;

entity sample_effects is
  port (
    clk        : in  std_logic;
    sample_in  : in  audio_sample_t;
    valid_in   : in  std_logic;
    efx_vol    : in  efx_param_t;
    efx_crush  : in  efx_param_t;
    efx_down   : in  efx_param_t;
    sample_out : out audio_sample_t;
    valid_out  : out std_logic
  );
end entity sample_effects;

architecture Behavioral of sample_effects is

  signal held_sample  : audio_sample_t := (others => '0');
  signal down_counter : natural range 0 to 15 := 0;

begin

  sample_out <= held_sample;

  process (clk)
    variable input_signed  : signed(AUDIO_SAMPLE_WIDTH-1 downto 0);
    variable volume_gain   : signed(EFX_PARAM_WIDTH downto 0);
    variable product       : signed(AUDIO_SAMPLE_WIDTH+EFX_PARAM_WIDTH downto 0);
    variable scaled_sample : signed(AUDIO_SAMPLE_WIDTH-1 downto 0);
    variable crushed       : audio_sample_t;
    variable crush_count   : natural range 0 to 2**EFX_PARAM_WIDTH-1;
  begin
    if rising_edge(clk) then
      valid_out <= '0';

      if valid_in = '1' then
        input_signed := signed(sample_in);

        -- volume: 0..14 = gain/16, 15 = unity
        if unsigned(efx_vol) = 2**EFX_PARAM_WIDTH-1 then
          scaled_sample := input_signed;
        else
          volume_gain := signed('0' & efx_vol);
          product     := input_signed * volume_gain;

          scaled_sample := resize(shift_right(product, EFX_PARAM_WIDTH), AUDIO_SAMPLE_WIDTH);
        end if;

        -- bit crush: zero N LSBs (sign bit preserved)
        crushed     := std_logic_vector(scaled_sample);
        crush_count := to_integer(unsigned(efx_crush));

        for bit_number in 0 to AUDIO_SAMPLE_WIDTH-2 loop
          if bit_number < crush_count then
            crushed(bit_number) := '0';
          end if;
        end loop;

        -- downsample: hold output for efx_down+1 input samples
        if down_counter = 0 then
          held_sample  <= crushed;
          down_counter <= to_integer(unsigned(efx_down));
        else
          down_counter <= down_counter - 1;
        end if;

        -- pulse on every input; held_sample only changes when counter hits 0
        valid_out <= '1';
      end if;
    end if;
  end process;

end architecture Behavioral;