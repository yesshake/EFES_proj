-- ================================================================
-- 
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_rx is
  port (
    bclk : in std_logic;
    lrclk : in std_logic;
    adc_dat : in std_logic;
    sample_out : out std_logic_vector(15 downto 0);
    valid : out std_logic
  );
end entity i2s_rx;

architecture Behavioral of i2s_rx is


begin


end architecture Behavioral;
