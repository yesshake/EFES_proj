-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity settings is
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
end entity settings;

architecture Behavioral of settings is


begin


end architecture Behavioral;
