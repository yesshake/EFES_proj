-- ================================================================
-- 
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  port (
    clk : in std_logic;
    rst_n : in std_logic;
    i2c_sclk : out std_logic;
    i2c_sdat : inout std_logic
  );
end entity i2c_master;

architecture Behavioral of i2c_master is


begin


end architecture Behavioral;
