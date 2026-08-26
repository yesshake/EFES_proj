-- ================================================================
-- FPGA mono audio processor
--
-- clk_50m domain:
--   PLL status, WM8731 I2C configuration, user settings, UART and HEX
--
-- aud_bclk domain:
--   I2S receive, audio effects, mono sample hold and I2S transmit
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;

entity sys_top is
  port (
    clk_50m : in std_logic;
    rst_n   : in std_logic;

    key : in std_logic_vector(3 downto 0);
    sw  : in std_logic_vector(9 downto 0);

    hex0 : out std_logic_vector(6 downto 0);
    hex1 : out std_logic_vector(6 downto 0);
    hex2 : out std_logic_vector(6 downto 0);
    hex3 : out std_logic_vector(6 downto 0);
    hex4 : out std_logic_vector(6 downto 0);
    hex5 : out std_logic_vector(6 downto 0);

    i2c_sdat : inout std_logic;
    i2c_sclk : inout std_logic;

    hps_i2c_control : out std_logic;

    aud_xck     : out std_logic;
    aud_bclk    : in  std_logic;
    aud_adclrck : in  std_logic;
    aud_adcdat  : in  std_logic;

    gpio_bclk     : out std_logic;
    gpio_lrclk    : out std_logic;
    gpio_dac_data : out std_logic;

    uart_rx : in  std_logic;
    uart_tx : out std_logic
  );
end entity sys_top;

architecture rtl of sys_top is

  component audio_pll is
    port (
      refclk   : in  std_logic;
      rst      : in  std_logic;
      outclk_0 : out std_logic;
      locked   : out std_logic
    );
  end component;

  ------------------------------------------------------------------
  -- Clock and codec-control signals: clk_50m domain.
  ------------------------------------------------------------------
  signal audio_mclk      : std_logic;
  signal pll_reset       : std_logic;
  signal pll_locked      : std_logic;
  signal pll_locked_meta : std_logic := '0';
  signal pll_locked_sync : std_logic := '0';

  signal codec_reset_n     : std_logic;
  signal codec_config_done : std_logic;
  signal codec_i2c_error   : std_logic;

  ------------------------------------------------------------------
  -- Codec status crossing into aud_bclk.
  ------------------------------------------------------------------
  signal codec_done_meta : std_logic := '0';
  signal codec_done_bclk : std_logic := '0';

  ------------------------------------------------------------------
  -- Audio datapath: aud_bclk domain.
  ------------------------------------------------------------------
  signal rx_sample         : std_logic_vector(15 downto 0);
  signal rx_valid          : std_logic;
  signal selected_rx_valid : std_logic;

  signal effect_sample : std_logic_vector(15 downto 0);
  signal effect_valid  : std_logic;

  signal tx_sample      : std_logic_vector(15 downto 0) := (others => '0');
  signal tx_ready       : std_logic := '0';
  signal tx_serial_data : std_logic;

  ------------------------------------------------------------------
  -- User settings and UART: clk_50m domain.
  ------------------------------------------------------------------
  signal btn_up_clean     : std_logic;
  signal btn_down_clean   : std_logic;
  signal btn_action_clean : std_logic;

  signal setting_volume : std_logic_vector(3 downto 0);
  signal setting_crush  : std_logic_vector(3 downto 0);
  signal setting_down   : std_logic_vector(3 downto 0);
  signal preset_index   : std_logic_vector(3 downto 0);

  signal save_strobe : std_logic;
  signal load_strobe : std_logic;

  signal uart_tx_data  : std_logic_vector(7 downto 0);
  signal uart_tx_start : std_logic;
  signal uart_tx_busy  : std_logic;

  signal uart_rx_byte  : std_logic_vector(7 downto 0);
  signal uart_rx_valid : std_logic;

  signal mcu_volume   : std_logic_vector(3 downto 0);
  signal mcu_crush    : std_logic_vector(3 downto 0);
  signal mcu_down     : std_logic_vector(3 downto 0);
  signal mcu_rx_valid : std_logic;

  ------------------------------------------------------------------
  -- Slowly-changing setting buses crossing into aud_bclk.
  ------------------------------------------------------------------
  signal volume_meta : std_logic_vector(3 downto 0) := (others => '0');
  signal volume_bclk : std_logic_vector(3 downto 0) := (others => '0');
  signal crush_meta  : std_logic_vector(3 downto 0) := (others => '0');
  signal crush_bclk  : std_logic_vector(3 downto 0) := (others => '0');
  signal down_meta   : std_logic_vector(3 downto 0) := (others => '0');
  signal down_bclk   : std_logic_vector(3 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------
  -- Fixed board-level connections.
  ------------------------------------------------------------------
  hps_i2c_control <= '0';

  aud_xck         <= audio_mclk;
  gpio_bclk       <= aud_bclk;
  gpio_lrclk      <= aud_adclrck;
  gpio_dac_data   <= tx_serial_data when codec_done_bclk = '1' else '0';

  ------------------------------------------------------------------
  -- Generate the WM8731 master clock.
  ------------------------------------------------------------------
  pll_reset <= not rst_n;

  U_audio_pll : audio_pll
    port map (
      refclk   => clk_50m,
      rst      => pll_reset,
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

  ------------------------------------------------------------------
  -- WM8731 configuration.
  ------------------------------------------------------------------
  U_i2c_master : entity work.i2c_master
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

  process (aud_bclk, rst_n)
  begin
    if rst_n = '0' then
      codec_done_meta <= '0';
      codec_done_bclk <= '0';
    elsif rising_edge(aud_bclk) then
      codec_done_meta <= codec_config_done;
      codec_done_bclk <= codec_done_meta;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Button debouncing and setting acquisition.
  -- Buttons are active-low; edge handling is performed by settings.
  ------------------------------------------------------------------
  U_debounce_up : entity work.debouncer
    port map (
      clk        => clk_50m,
      button_in  => key(0),
      button_out => btn_up_clean
    );

  U_debounce_down : entity work.debouncer
    port map (
      clk        => clk_50m,
      button_in  => key(1),
      button_out => btn_down_clean
    );

  U_debounce_action : entity work.debouncer
    port map (
      clk        => clk_50m,
      button_in  => key(2),
      button_out => btn_action_clean
    );

  U_settings : entity work.settings
    port map (
      clk          => clk_50m,
      rst_n        => rst_n,
      btn_up       => btn_up_clean,
      btn_down     => btn_down_clean,
      btn_mode     => sw(2 downto 0),
      btn_save     => btn_action_clean,
      mcu_vol      => mcu_volume,
      mcu_crush    => mcu_crush,
      mcu_down     => mcu_down,
      mcu_rx_valid => mcu_rx_valid,
      efx_vol      => setting_volume,
      efx_crush    => setting_crush,
      efx_down     => setting_down,
      preset_idx   => preset_index,
      save_strobe  => save_strobe,
      load_strobe  => load_strobe
    );

  ------------------------------------------------------------------
  -- Decimal setting displays.
  -- HEX1:HEX0 = volume, HEX3:HEX2 = crush, HEX5:HEX4 = downsample.
  ------------------------------------------------------------------
  U_hex_volume : entity work.hex_display
    port map (
      value    => setting_volume,
      hex_tens => hex1,
      hex_ones => hex0
    );

  U_hex_crush : entity work.hex_display
    port map (
      value    => setting_crush,
      hex_tens => hex3,
      hex_ones => hex2
    );

  U_hex_downsample : entity work.hex_display
    port map (
      value    => setting_down,
      hex_tens => hex5,
      hex_ones => hex4
    );

  ------------------------------------------------------------------
  -- UART physical receiver and transmitter.
  ------------------------------------------------------------------
  U_uart_rx : entity work.uart_rx
    generic map (
      CLK_FREQ_HZ => 50_000_000,
      BAUD_RATE    => 115_200
    )
    port map (
      clk        => clk_50m,
      rst_n      => rst_n,
      uart_rx_i  => uart_rx,
      data_out   => uart_rx_byte,
      data_valid => uart_rx_valid
    );

  U_uart_setting_interface : entity work.UART_setting_interface
    port map (
      clk           => clk_50m,
      rst_n         => rst_n,
      rx_data       => uart_rx_byte,
      rx_valid      => uart_rx_valid,
      save_strobe   => save_strobe,
      load_strobe   => load_strobe,
      preset_idx_in => preset_index,
      efx_vol_in    => setting_volume,
      efx_crush_in  => setting_crush,
      efx_down_in   => setting_down,
      tx_data       => uart_tx_data,
      tx_start      => uart_tx_start,
      tx_busy       => uart_tx_busy,
      mcu_vol_out   => mcu_volume,
      mcu_crush_out => mcu_crush,
      mcu_down_out  => mcu_down,
      mcu_rx_valid  => mcu_rx_valid
    );

  U_uart_tx : entity work.uart_tx
    generic map (
      CLK_FREQ  => 50_000_000,
      BAUD_RATE => 115_200
    )
    port map (
      clk      => clk_50m,
      rst_n    => rst_n,
      tx_data  => uart_tx_data,
      tx_start => uart_tx_start,
      tx_busy  => uart_tx_busy,
      tx_line  => uart_tx
    );

  ------------------------------------------------------------------
  -- Synchronize slowly-changing effect controls into aud_bclk.
  -- Per-bit two-stage synchronization is sufficient for these manual
  -- controls because they remain stable for many audio clock cycles.
  ------------------------------------------------------------------
  process (aud_bclk, rst_n)
  begin
    if rst_n = '0' then
      volume_meta <= (others => '0');
      volume_bclk <= (others => '0');
      crush_meta  <= (others => '0');
      crush_bclk  <= (others => '0');
      down_meta   <= (others => '0');
      down_bclk   <= (others => '0');
    elsif rising_edge(aud_bclk) then
      volume_meta <= setting_volume;
      volume_bclk <= volume_meta;
      crush_meta  <= setting_crush;
      crush_bclk  <= crush_meta;
      down_meta   <= setting_down;
      down_bclk   <= down_meta;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Mono audio datapath.
  ------------------------------------------------------------------
  U_i2s_rx : entity work.i2s_rx
    port map (
      bclk       => aud_bclk,
      lrclk      => aud_adclrck,
      adc_dat    => aud_adcdat,
      sample_out => rx_sample,
      valid      => rx_valid
    );

  -- This uses the left I2S slot. The receiver asserts rx_valid while
  -- LRCLK still identifies the slot whose sample has just completed.
  selected_rx_valid <= rx_valid when aud_adclrck = '0' else '0';

  U_sample_effects : entity work.sample_effects
    port map (
      clk        => aud_bclk,
      sample_in  => rx_sample,
      valid_in   => selected_rx_valid,
      efx_vol    => volume_bclk,
      efx_crush  => crush_bclk,
      efx_down   => down_bclk,
      sample_out => effect_sample,
      valid_out  => effect_valid
    );

  -- Hold the processed mono sample. i2s_tx loads the same held value
  -- at each LRCLK transition, repeating it in both output slots.
  process (aud_bclk, rst_n)
  begin
    if rst_n = '0' then
      tx_sample <= (others => '0');
      tx_ready  <= '0';
    elsif rising_edge(aud_bclk) then
      if codec_done_bclk = '0' then
        tx_sample <= (others => '0');
        tx_ready  <= '0';
      elsif effect_valid = '1' then
        tx_sample <= effect_sample;
        tx_ready  <= '1';
      end if;
    end if;
  end process;

  U_i2s_tx : entity work.i2s_tx
    port map (
      bclk      => aud_bclk,
      lrclk     => aud_adclrck,
      sample_in => tx_sample,
      valid_in  => tx_ready,
      dac_data  => tx_serial_data
    );

end architecture rtl;
