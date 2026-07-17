-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
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
end entity uart_tx;

architecture Behavioral of uart_tx is


begin


end architecture Behavioral;
