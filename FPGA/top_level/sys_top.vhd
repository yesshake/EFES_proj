-- ================================================================
-- 
-- 
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sys_top is
  port (
    clk_50m : in std_logic;
    rst_n : in std_logic;
    key : in std_logic_vector(3 downto 0);
    sw : in std_logic_vector(9 downto 0);
    hex0 : out std_logic_vector(6 downto 0);
    hex1 : out std_logic_vector(6 downto 0);
    hex2 : out std_logic_vector(6 downto 0);
    i2c_sdat : inout std_logic;
    i2c_sclk : out std_logic;
    aud_xck : out std_logic;
    aud_bclk : out std_logic;
    aud_adclrck : out std_logic;
    aud_daclrck : out std_logic;
    aud_adcdat : in std_logic;
    gpio_bclk : out std_logic;
    gpio_lrclk : out std_logic;
    gpio_dac_data : out std_logic;
    uart_rx : in std_logic;
    uart_tx : out std_logic
  );
end entity sys_top;

architecture Behavioral of sys_top is

  component i2c_master is
    port (
      clk : in std_logic;
      rst_n : in std_logic;
      i2c_sclk : out std_logic;
      i2c_sdat : inout std_logic
    );
  end component;
  -- U_i2c_master : i2c_master
  --   port map (
  --     clk      => ,
  --     rst_n    => ,
  --     i2c_sclk => ,
  --     i2c_sdat => 
  --   );

  component i2s_rx is
    port (
      bclk : in std_logic;
      lrclk : in std_logic;
      adc_dat : in std_logic;
      sample_out : out std_logic_vector(15 downto 0);
      valid : out std_logic
    );
  end component;
  -- U_i2s_rx : i2s_rx
  --   port map (
  --     bclk       => ,
  --     lrclk      => ,
  --     adc_dat    => ,
  --     sample_out => ,
  --     valid      => 
  --   );

  component sample_effects is
    port (
      clk : in std_logic;
      sample_in : in std_logic_vector(15 downto 0);
      valid_in : in std_logic;
      efx_vol : in std_logic_vector(3 downto 0);
      efx_crush : in std_logic_vector(3 downto 0);
      efx_down : in std_logic_vector(3 downto 0);
      sample_out : out std_logic_vector(15 downto 0);
      valid_out : out std_logic
    );
  end component;
  -- U_sample_effects : sample_effects
  --   port map (
  --     clk        => ,
  --     sample_in  => ,
  --     valid_in   => ,
  --     efx_vol    => ,
  --     efx_crush  => ,
  --     efx_down   => ,
  --     sample_out => ,
  --     valid_out  => 
  --   );

  component i2s_tx is
    port (
      bclk : in std_logic;
      lrclk : in std_logic;
      sample_in : in std_logic_vector(15 downto 0);
      valid_in : in std_logic;
      dac_data : out std_logic
    );
  end component;
  -- U_i2s_tx : i2s_tx
  --   port map (
  --     bclk      => ,
  --     lrclk     => ,
  --     sample_in => ,
  --     valid_in  => ,
  --     dac_data  => 
  --   );

  component debouncer is
    generic (
      CLK_FREQ : integer := 50000000;
      DEBOUNCE_MS : integer := 20
    );
    port (
      clk : in std_logic;
      button_in : in std_logic;
      button_out : out std_logic
    );
  end component;
  -- U_debouncer : debouncer
  --   generic map (
  --     CLK_FREQ    => ,
  --     DEBOUNCE_MS => 
  --   )
  --   port map (
  --     clk        => ,
  --     button_in  => ,
  --     button_out => 
  --   );

  component settings is
    port (
      clk : in std_logic;
      rst_n : in std_logic;
      btn_up : in std_logic;
      btn_down : in std_logic;
      btn_mode : in std_logic_vector(1 downto 0);
      btn_save : in std_logic;
      mcu_vol : in std_logic_vector(3 downto 0);
      mcu_crush : in std_logic_vector(3 downto 0);
      mcu_down : in std_logic_vector(3 downto 0);
      mcu_rx_valid : in std_logic;
      efx_vol : out std_logic_vector(3 downto 0);
      efx_crush : out std_logic_vector(3 downto 0);
      efx_down : out std_logic_vector(3 downto 0);
      preset_idx : out std_logic_vector(3 downto 0);
      save_strobe : out std_logic;
      load_strobe : out std_logic
    );
  end component;
  -- U_settings : settings
  --   port map (
  --     clk          => ,
  --     rst_n        => ,
  --     btn_up       => ,
  --     btn_down     => ,
  --     btn_mode     => ,
  --     btn_save     => ,
  --     mcu_vol      => ,
  --     mcu_crush    => ,
  --     mcu_down     => ,
  --     mcu_rx_valid => ,
  --     efx_vol      => ,
  --     efx_crush    => ,
  --     efx_down     => ,
  --     preset_idx   => ,
  --     save_strobe  => ,
  --     load_strobe  => 
  --   );

  component hex_display is
    port (
      active_param : in std_logic_vector(1 downto 0);
      param_val : in std_logic_vector(3 downto 0);
      preset_idx : in std_logic_vector(3 downto 0);
      hex_param : out std_logic_vector(6 downto 0);
      hex_val : out std_logic_vector(6 downto 0);
      hex_preset : out std_logic_vector(6 downto 0)
    );
  end component;
  -- U_hex_display : hex_display
  --   port map (
  --     active_param => ,
  --     param_val    => ,
  --     preset_idx   => ,
  --     hex_param    => ,
  --     hex_val      => ,
  --     hex_preset   => 
  --   );

  component uart_tx is
    generic (
      CLK_FREQ : integer := 50000000;
      BAUD_RATE : integer := 115200
    );
    port (
      clk : in std_logic;
      tx_data : in std_logic_vector(7 downto 0);
      tx_start : in std_logic;
      tx_busy : out std_logic;
      tx_line : out std_logic
    );
  end component;
  -- U_uart_tx : uart_tx
  --   generic map (
  --     CLK_FREQ  => ,
  --     BAUD_RATE => 
  --   )
  --   port map (
  --     clk      => ,
  --     tx_data  => ,
  --     tx_start => ,
  --     tx_busy  => ,
  --     tx_line  => 
  --   );

  component uart_rx is
    generic (
      CLK_FREQ : integer := 50000000;
      BAUD_RATE : integer := 115200
    );
    port (
      clk : in std_logic;
      rx_line : in std_logic;
      rx_data : out std_logic_vector(7 downto 0);
      rx_valid : out std_logic
    );
  end component;
  -- U_uart_rx : uart_rx
  --   generic map (
  --     CLK_FREQ  => ,
  --     BAUD_RATE => 
  --   )
  --   port map (
  --     clk      => ,
  --     rx_line  => ,
  --     rx_data  => ,
  --     rx_valid => 
  --   );

  component UART_setting_interface is
    port (
      clk : in std_logic;
      rst_n : in std_logic;
      rx_data : in std_logic_vector(7 downto 0);
      rx_valid : in std_logic;
      save_strobe : in std_logic;
      load_strobe : in std_logic;
      preset_idx_in : in std_logic_vector(3 downto 0);
      efx_vol_in : in std_logic_vector(3 downto 0);
      efx_crush_in : in std_logic_vector(3 downto 0);
      efx_down_in : in std_logic_vector(3 downto 0);
      tx_data : out std_logic_vector(7 downto 0);
      tx_start : out std_logic;
      tx_busy : in std_logic;
      mcu_vol_out : out std_logic_vector(3 downto 0);
      mcu_crush_out : out std_logic_vector(3 downto 0);
      mcu_down_out : out std_logic_vector(3 downto 0);
      mcu_rx_valid : out std_logic
    );
  end component;
  -- U_UART_setting_interface : UART_setting_interface
  --   port map (
  --     clk           => ,
  --     rst_n         => ,
  --     rx_data       => ,
  --     rx_valid      => ,
  --     save_strobe   => ,
  --     load_strobe   => ,
  --     preset_idx_in => ,
  --     efx_vol_in    => ,
  --     efx_crush_in  => ,
  --     efx_down_in   => ,
  --     tx_data       => ,
  --     tx_start      => ,
  --     tx_busy       => ,
  --     mcu_vol_out   => ,
  --     mcu_crush_out => ,
  --     mcu_down_out  => ,
  --     mcu_rx_valid  => 
  --   );

-- USER SIGNALS BEGIN

-- USER SIGNALS END

begin


end architecture Behavioral;
