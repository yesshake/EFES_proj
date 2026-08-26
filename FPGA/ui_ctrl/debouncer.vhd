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

  function max_one(value : natural) return positive is
  begin
    if value = 0 then
      return 1;
    end if;
    return value;
  end function;

  constant DEBOUNCE_CYCLES : positive := max_one((CLK_FREQ / 1000) * DEBOUNCE_MS);

  signal button_meta   : std_logic := '1';
  signal button_sync   : std_logic := '1';
  signal button_stable : std_logic := '1';

  signal count : natural range 0 to DEBOUNCE_CYCLES - 1 := 0;
begin

  button_out <= button_stable;

  process (clk)
  begin
    if rising_edge(clk) then
      
      button_meta <= button_in;
      button_sync <= button_meta;

      if button_sync = button_stable then
        count <= 0;
      elsif count = DEBOUNCE_CYCLES - 1 then
        button_stable <= button_sync;
        count         <= 0;

      else
        count <= count + 1;
      end if;
    end if;
  end process;
end architecture Behavioral;