-- ============================================================================
-- Stage-1 system testbench
--
-- Checks:
--   * the generated codec MCLK is approximately 18.432 MHz;
--   * the WM8731 I2C write sequence contains the expected eight words;
--   * the codec model ACKs all three bytes of every I2C transaction;
--   * BCLK and LRCLK are forwarded to the external amplifier interface;
--   * only the LRCLK-low input slot is retained;
--   * the retained mono sample is transmitted in both I2S output slots.
--
-- The WM8731 model below is intentionally minimal. It implements only the
-- fixed-purpose behavior needed for Stage 1: write ACKs and I2S master clocks.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;

use work.wm8731_pkg.all;

entity tb_stage_1 is
end entity tb_stage_1;

architecture sim of tb_stage_1 is

  constant CLK_50M_PERIOD   : time := 20 ns;
  constant BCLK_HALF_PERIOD : time := 162.76 ns; -- approximately 3.072 MHz

  type byte_array_t is array (natural range <>) of
    std_logic_vector(7 downto 0);

  signal clk_50m : std_logic := '0';
  signal rst_n   : std_logic := '0';

  signal key : std_logic_vector(3 downto 0) := (others => '1');
  signal sw  : std_logic_vector(9 downto 0) := (others => '0');

  signal hex0 : std_logic_vector(6 downto 0);
  signal hex1 : std_logic_vector(6 downto 0);
  signal hex2 : std_logic_vector(6 downto 0);

  signal i2c_sdat : std_logic := 'H';
  signal i2c_sclk : std_logic := 'H';
  signal codec_sda_drive_low : std_logic := '0';

  signal hps_i2c_control : std_logic;

  signal aud_xck     : std_logic;
  signal aud_bclk    : std_logic := '0';
  signal aud_adclrck : std_logic := '0';
  signal aud_adcdat  : std_logic := '0';

  signal gpio_bclk     : std_logic;
  signal gpio_lrclk    : std_logic;
  signal gpio_dac_data : std_logic;

  signal uart_rx : std_logic := '1';
  signal uart_tx : std_logic;

  signal i2c_config_complete : std_logic := '0';
  signal pll_check_complete  : std_logic := '0';
  signal audio_check_complete : std_logic := '0';
  signal test_finished        : std_logic := '0';

  procedure receive_i2c_byte (
    signal scl  : in  std_logic;
    signal sda  : in  std_logic;
    variable value : out std_logic_vector(7 downto 0)
  ) is
  begin
    for bit_number in 7 downto 0 loop
      wait until scl'event and to_x01(scl) = '1';
      value(bit_number) := to_x01(sda);
    end loop;
  end procedure;

  procedure acknowledge_i2c_byte (
    signal scl       : in  std_logic;
    signal drive_low : out std_logic
  ) is
  begin
    -- Begin driving ACK after the eighth data-bit falling edge.
    wait until scl'event and to_x01(scl) = '0';
    drive_low <= '1';

    -- Hold ACK throughout the ninth SCL high period.
    wait until scl'event and to_x01(scl) = '1';
    wait until scl'event and to_x01(scl) = '0';
    drive_low <= '0';
  end procedure;

  procedure send_i2s_slot (
    signal bclk       : in  std_logic;
    signal lrclk      : out std_logic;
    signal serial_dat : out std_logic;
    constant channel  : in  std_logic;
    constant sample   : in  std_logic_vector(15 downto 0)
  ) is
  begin
    -- Change LRCLK after a rising edge so it is stable at the following
    -- falling edge, where i2s_tx detects the new slot. The next bit period
    -- is the standard-I2S one-bit delay.
    wait until rising_edge(bclk);
    lrclk      <= channel;
    serial_dat <= '0';

    wait until falling_edge(bclk);

    -- The WM8731 changes ADC data on falling edges; i2s_rx samples it on
    -- the following rising edges.
    for bit_number in 15 downto 0 loop
      wait until falling_edge(bclk);
      serial_dat <= sample(bit_number);
    end loop;

    -- Complete a 32-bit I2S slot. The receiver ignores these extra bits.
    for padding_bit in 1 to 15 loop
      wait until falling_edge(bclk);
      serial_dat <= '0';
    end loop;
  end procedure;

begin

  DUT : entity work.sys_top
    port map (
      clk_50m => clk_50m,
      rst_n   => rst_n,

      key => key,
      sw  => sw,

      hex0 => hex0,
      hex1 => hex1,
      hex2 => hex2,

      i2c_sdat        => i2c_sdat,
      i2c_sclk        => i2c_sclk,
      hps_i2c_control => hps_i2c_control,

      aud_xck     => aud_xck,
      aud_bclk    => aud_bclk,
      aud_adclrck => aud_adclrck,
      aud_adcdat  => aud_adcdat,

      gpio_bclk     => gpio_bclk,
      gpio_lrclk    => gpio_lrclk,
      gpio_dac_data => gpio_dac_data,

      uart_rx => uart_rx,
      uart_tx => uart_tx
    );

  -- External pull-ups and the codec's open-drain ACK driver.
  i2c_sclk <= 'H';
  i2c_sdat <= 'H';
  i2c_sdat <= '0' when codec_sda_drive_low = '1' else 'Z';

  clk_50m_generator : process
  begin
    while test_finished = '0' loop
      clk_50m <= '0';
      wait for CLK_50M_PERIOD / 2;
      clk_50m <= '1';
      wait for CLK_50M_PERIOD / 2;
    end loop;
    wait;
  end process;

  reset_stimulus : process
  begin
    rst_n <= '0';
    wait for 500 ns;
    rst_n <= '1';

    -- Reset the PLL after the checks complete so a VHDL-93 run can end
    -- naturally without relying on std.env.finish (a VHDL-2008 feature).
    wait until test_finished = '1';
    rst_n <= '0';
    wait;
  end process;

  -- The real WM8731 begins generating BCLK only after it has been configured.
  codec_bclk_generator : process
  begin
    wait until i2c_config_complete = '1';

    while test_finished = '0' loop
      aud_bclk <= '0';
      wait for BCLK_HALF_PERIOD;
      aud_bclk <= '1';
      wait for BCLK_HALF_PERIOD;
    end loop;
    wait;
  end process;

pll_frequency_check : process
  constant MEASURED_CYCLES : positive := 100;

  variable start_time     : time;
  variable average_period : time;
begin
  wait until rst_n = '1';

  -- Allow the vendor PLL model to lock and finish phase adjustment.
  wait for 2 us;

  wait until rising_edge(aud_xck);
  start_time := now;

  for i in 1 to MEASURED_CYCLES loop
    wait until rising_edge(aud_xck);
  end loop;

  average_period :=
    (now - start_time) / MEASURED_CYCLES;

  report "Average aud_xck period = " &
         time'image(average_period)
    severity note;

  assert average_period > 53 ns and
         average_period < 55 ns
    report "aud_xck is not approximately 18.432 MHz"
    severity failure;

  pll_check_complete <= '1';
  wait;
end process;

  -- Minimal WM8731 I2C target model. It checks each transmitted byte and
  -- supplies an ACK after the address and both control bytes.
  codec_i2c_model : process
    variable received_bytes : byte_array_t(0 to 2);
  begin
    codec_sda_drive_low <= '0';
    wait until rst_n = '1';

    for config_index in WM8731_CONFIG_WORDS'range loop
      -- START is SDA falling while SCL is high.
      wait until i2c_sdat'event and
                 to_x01(i2c_sdat) = '0' and
                 to_x01(i2c_sclk) = '1';

      for byte_index in received_bytes'range loop
        receive_i2c_byte(i2c_sclk, i2c_sdat, received_bytes(byte_index));
        acknowledge_i2c_byte(i2c_sclk, codec_sda_drive_low);
      end loop;

      -- STOP is SDA rising while SCL is high.
      wait until i2c_sdat'event and
                 to_x01(i2c_sdat) = '1' and
                 to_x01(i2c_sclk) = '1';

      assert received_bytes(0) = WM8731_WRITE_BYTE
        report "Incorrect WM8731 I2C address byte at configuration index " &
               integer'image(config_index)
        severity failure;

      assert received_bytes(1) =
             WM8731_CONFIG_WORDS(config_index)(15 downto 8)
        report "Incorrect first control byte at configuration index " &
               integer'image(config_index)
        severity failure;

      assert received_bytes(2) =
             WM8731_CONFIG_WORDS(config_index)(7 downto 0)
        report "Incorrect second control byte at configuration index " &
               integer'image(config_index)
        severity failure;
    end loop;

    i2c_config_complete <= '1';
    report "All WM8731 configuration words received and ACKed" severity note;
    wait;
  end process;

  amplifier_clock_check : process
  begin
    wait on aud_bclk;
    wait for 0 ns;
    assert gpio_bclk = aud_bclk
      report "gpio_bclk does not follow aud_bclk"
      severity failure;
  end process;

  amplifier_lrclk_check : process
  begin
    wait on aud_adclrck;
    wait for 0 ns;
    assert gpio_lrclk = aud_adclrck
      report "gpio_lrclk does not follow aud_adclrck"
      severity failure;
  end process;

  audio_stimulus : process
  begin
    wait until i2c_config_complete = '1';

    -- Allow the I2C controller to enter FINISHED and allow its done signal
    -- to cross into the newly started BCLK domain.
    wait for 20 us;

    -- LRCLK low is the selected microphone slot. Right-slot values are made
    -- deliberately different so an accidental stereo capture is detected.
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '1', x"5AA5");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '0', x"1234");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '1', x"DEAD");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '0', x"FEDC");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '1', x"BEEF");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '0', x"8001");
    send_i2s_slot(aud_bclk, aud_adclrck, aud_adcdat, '1', x"CAFE");

    wait until audio_check_complete = '1';
    wait;
  end process;

  -- Decode the MAX98357A input stream. The first rising edge after an LRCLK
  -- transition is the I2S delay; the following sixteen edges carry the sample.
  amplifier_data_check : process
    variable slot_number    : natural := 0;
    variable decoded_sample : std_logic_vector(15 downto 0);
  begin
    wait until i2c_config_complete = '1';

    loop
      wait until aud_adclrck'event;
      slot_number := slot_number + 1;

      wait until rising_edge(aud_bclk); -- standard-I2S delay bit

      for bit_number in 15 downto 0 loop
        wait until rising_edge(aud_bclk);
        decoded_sample(bit_number) := gpio_dac_data;
      end loop;

      case slot_number is
        when 3 | 4 =>
          assert decoded_sample = x"1234"
            report "Mono sample 0x1234 was not repeated into both slots"
            severity failure;

        when 5 | 6 =>
          assert decoded_sample = x"FEDC"
            report "Mono sample 0xFEDC was not repeated into both slots"
            severity failure;

        when 7 =>
          assert decoded_sample = x"8001"
            report "Mono sample 0x8001 was not transmitted in the right slot"
            severity failure;

          audio_check_complete <= '1';
          wait;

        when others =>
          null;
      end case;
    end loop;
  end process;

  fixed_connection_check : process
  begin
    wait for 1 us;
    assert hps_i2c_control = '0'
      report "hps_i2c_control must select FPGA ownership"
      severity failure;

    while i2c_config_complete = '0' loop
      assert gpio_dac_data = '0'
        report "Amplifier data must remain muted before codec configuration"
        severity failure;
      wait for 10 us;
    end loop;
    wait;
  end process;

  test_completion : process
  begin
    wait until pll_check_complete = '1' and
               i2c_config_complete = '1' and
               audio_check_complete = '1';

    report "STAGE 1 TEST PASSED" severity note;
    test_finished <= '1';
    wait;
  end process;

  watchdog : process
  begin
    wait for 20 ms;
    assert test_finished = '1'
      report "Stage-1 testbench timed out"
      severity failure;
    wait;
  end process;

end architecture sim;
