-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_effects is
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
end entity sample_effects;

architecture Behavioral of sample_effects is


begin


end architecture Behavioral;
