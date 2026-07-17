-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_tx is
  port (
    bclk : in std_logic;
    lrclk : in std_logic;
    sample_in : in std_logic_vector(15 downto 0);
    valid_in : in std_logic;
    dac_data : out std_logic
  );
end entity i2s_tx;

architecture Behavioral of i2s_tx is


begin


end architecture Behavioral;
