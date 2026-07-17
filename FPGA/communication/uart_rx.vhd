-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
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
end entity uart_rx;

architecture Behavioral of uart_rx is


begin


end architecture Behavioral;
