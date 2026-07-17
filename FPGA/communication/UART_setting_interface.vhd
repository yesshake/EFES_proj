-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_setting_interface is
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
end entity UART_setting_interface;

architecture Behavioral of UART_setting_interface is


begin


end architecture Behavioral;
