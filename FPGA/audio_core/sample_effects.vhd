library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_effects is
  port (
    clk        : in  std_logic;
    sample_in  : in  std_logic_vector(15 downto 0);
    valid_in   : in  std_logic;
    efx_vol    : in  std_logic_vector(3 downto 0);
    efx_crush  : in  std_logic_vector(3 downto 0);
    efx_down   : in  std_logic_vector(3 downto 0);
    sample_out : out std_logic_vector(15 downto 0);
    valid_out  : out std_logic
  );
end entity sample_effects;

architecture Behavioral of sample_effects is

  signal held_sample  : std_logic_vector(15 downto 0) := (others => '0');
  signal down_counter : natural range 0 to 15 := 0;

begin

  sample_out <= held_sample;

  process (clk)
    variable input_signed  : signed(15 downto 0);
    variable volume_gain   : signed(4 downto 0);
    variable product       : signed(20 downto 0);
    variable scaled_sample : signed(15 downto 0);
    variable crushed       : std_logic_vector(15 downto 0);
    variable crush_count   : natural range 0 to 15;
  begin
    if rising_edge(clk) then
      valid_out <= '0';

      if valid_in = '1' then
        input_signed := signed(sample_in);

        ------------------------------------------------------------
        -- Volume
        --
        -- Levels 0..14 use gain/16.
        -- Level 15 is treated as exact unity gain.
        ------------------------------------------------------------
        if unsigned(efx_vol) = 15 then
          scaled_sample := input_signed;
        else
          volume_gain := signed('0' & efx_vol);
          product     := input_signed * volume_gain;

          scaled_sample := resize(shift_right(product, 4), 16);
        end if;

        ------------------------------------------------------------
        -- Bit crushing
        --
        -- Clear the requested number of least significant bits.
        -- Bit 15, the sign bit, is never cleared.
        ------------------------------------------------------------
        crushed     := std_logic_vector(scaled_sample);
        crush_count := to_integer(unsigned(efx_crush));

        for bit_number in 0 to 14 loop
          if bit_number < crush_count then
            crushed(bit_number) := '0';
          end if;
        end loop;

        ------------------------------------------------------------
        -- Downsampling
        --
        -- efx_down = 0: update every valid sample
        -- efx_down = 1: update every 2 valid samples
        -- ...
        -- efx_down = 15: update every 16 valid samples
        ------------------------------------------------------------
        if down_counter = 0 then
          held_sample  <= crushed;
          down_counter <= to_integer(unsigned(efx_down));
        else
          down_counter <= down_counter - 1;
        end if;

        -- Pulse for every input sample. held_sample remains unchanged
        -- during the downsampling hold period.
        valid_out <= '1';
      end if;
    end if;
  end process;

end architecture Behavioral;