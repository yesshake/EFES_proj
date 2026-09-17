-- Minimal hardware-smoke wrapper for the DE1-SoC audio path.
--
-- Only the clock, reset, codec, and external-I2S-output signals are
-- exposed as pins.  Unused user-interface and UART ports are tied off.

library ieee;
use ieee.std_logic_1164.all;

entity sys_top_smoke is
  port (
    clk_50m : in std_logic;
    rst_n   : in std_logic;

    i2c_sdat : inout std_logic;
    i2c_sclk : inout std_logic;

    aud_xck     : out std_logic;
    aud_bclk    : in  std_logic;
    aud_adclrck : in  std_logic;
    aud_adcdat  : in  std_logic;

    gpio_bclk     : out std_logic;
    gpio_lrclk    : out std_logic;
    gpio_dac_data : out std_logic
  );
end entity sys_top_smoke;

architecture rtl of sys_top_smoke is
begin

  U_system : entity work.sys_top
    port map (
      clk_50m => clk_50m,
      rst_n   => rst_n,

      -- Active-low buttons released; volume-control mode selected.
      key => (others => '1'),
      sw  => (others => '0'),

      hex0 => open,
      hex1 => open,
      hex2 => open,
      hex3 => open,
      hex4 => open,
      hex5 => open,

      i2c_sdat => i2c_sdat,
      i2c_sclk => i2c_sclk,

      -- This is an HPS-side board control, not a fabric I/O pin.
      hps_i2c_control => open,

      aud_xck     => aud_xck,
      aud_bclk    => aud_bclk,
      aud_adclrck => aud_adclrck,
      aud_adcdat  => aud_adcdat,

      gpio_bclk     => gpio_bclk,
      gpio_lrclk    => gpio_lrclk,
      gpio_dac_data => gpio_dac_data,

      -- Keep the unused UART receiver at its idle level.
      uart_rx => '1',
      uart_tx => open
    );

end architecture rtl;
