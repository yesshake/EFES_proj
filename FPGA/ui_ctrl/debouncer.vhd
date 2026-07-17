-- ================================================================
--
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
  generic (
    CLK_FREQ : integer := 50000000;
    DEBOUNCE_MS : integer := 20
  );
  port (
    clk : in std_logic;
    button_in : in std_logic;
    button_out : out std_logic
  );
end entity debouncer;

architecture Behavioral of debouncer is


begin


end architecture Behavioral;
