-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_display is
  port (
    active_param : in std_logic_vector(1 downto 0);
    param_val : in std_logic_vector(3 downto 0);
    preset_idx : in std_logic_vector(3 downto 0);
    hex_param : out std_logic_vector(6 downto 0);
    hex_val : out std_logic_vector(6 downto 0);
    hex_preset : out std_logic_vector(6 downto 0)
  );
end entity hex_display;

architecture Behavioral of hex_display is

begin


end architecture Behavioral;
