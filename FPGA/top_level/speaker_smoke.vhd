-- WM8731 microphone-to-MAX98357A direct I2S smoke test.
--
-- This top level deliberately bypasses i2s_rx, sample_effects, and i2s_tx.
-- It only starts/configures the WM8731 and forwards the codec's raw ADC
-- I2S stream to the external amplifier.

library ieee;
use ieee.std_logic_1164.all;

entity speaker_smoke is
  port (
    clk_50m : in std_logic;
    rst_n   : in std_logic;

    -- FPGA control bus to the WM8731.
    i2c_sdat : inout std_logic;
    i2c_sclk : inout std_logic;

    -- WM8731 clock and ADC I2S interface.
    aud_xck     : out std_logic;
    aud_bclk    : in  std_logic;
    aud_adclrck : in  std_logic;
    aud_adcdat  : in  std_logic;

    -- I2S interface to the external MAX98357A amplifier.
    gpio_bclk     : out std_logic;
    gpio_lrclk    : out std_logic;
    gpio_dac_data : out std_logic
  );
end entity speaker_smoke;

architecture rtl of speaker_smoke is

  component audio_pll is
    port (
      refclk   : in  std_logic;
      rst      : in  std_logic;
      outclk_0 : out std_logic;
      locked   : out std_logic
    );
  end component;

  component i2c_master is
    generic (
      CLK_FREQ_HZ      : positive := 50_000_000;
      I2C_FREQ_HZ      : positive := 100_000;
      STARTUP_DELAY_MS : positive := 10
    );
    port (
      clk       : in    std_logic;
      rst_n     : in    std_logic;
      i2c_sclk  : inout std_logic;
      i2c_sdat  : inout std_logic;
      done      : out   std_logic;
      ack_error : out   std_logic
    );
  end component;

  signal audio_mclk : std_logic;
  signal pll_locked : std_logic;

  signal pll_locked_meta : std_logic := '0';
  signal pll_locked_sync : std_logic := '0';

  signal codec_reset_n     : std_logic;
  signal codec_config_done : std_logic;
  signal codec_i2c_error   : std_logic;

begin

  ------------------------------------------------------------------
  -- WM8731 master clock and startup configuration.
  ------------------------------------------------------------------
  aud_xck <= audio_mclk;

  U_audio_pll : audio_pll
    port map (
      refclk   => clk_50m,
      rst      => not rst_n,
      outclk_0 => audio_mclk,
      locked   => pll_locked
    );

  process (clk_50m, rst_n)
  begin
    if rst_n = '0' then
      pll_locked_meta <= '0';
      pll_locked_sync <= '0';
    elsif rising_edge(clk_50m) then
      pll_locked_meta <= pll_locked;
      pll_locked_sync <= pll_locked_meta;
    end if;
  end process;

  codec_reset_n <= rst_n and pll_locked_sync;

  U_i2c_master : i2c_master
    generic map (
      CLK_FREQ_HZ      => 50_000_000,
      I2C_FREQ_HZ      => 100_000,
      STARTUP_DELAY_MS => 10
    )
    port map (
      clk       => clk_50m,
      rst_n     => codec_reset_n,
      i2c_sclk  => i2c_sclk,
      i2c_sdat  => i2c_sdat,
      done      => codec_config_done,
      ack_error => codec_i2c_error
    );

  ------------------------------------------------------------------
  -- Raw I2S bridge: WM8731 ADC directly to MAX98357A.
  ------------------------------------------------------------------
  gpio_bclk     <= aud_bclk;
  gpio_lrclk    <= aud_adclrck;
  gpio_dac_data <= aud_adcdat;

end architecture rtl;
