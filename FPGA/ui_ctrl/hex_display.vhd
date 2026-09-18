library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.efes_pkg.all;

entity hex_display is
  port (
    value     : in  efx_param_t;
    hex_tens  : out seven_seg_t;
    hex_ones  : out seven_seg_t
  );
end entity hex_display;

architecture rtl of hex_display is

  function encode_decimal(digit : natural) return std_logic_vector is
  begin
    case digit is
      when 0      => return "1000000";
      when 1      => return "1111001";
      when 2      => return "0100100";
      when 3      => return "0110000";
      when 4      => return "0011001";
      when 5      => return "0010010";
      when 6      => return "0000010";
      when 7      => return "1111000";
      when 8      => return "0000000";
      when 9      => return "0010000";
      when others => return "1111111";
    end case;
  end function;

begin

  process (value)
    variable number : natural range 0 to 15;
    variable tens   : natural range 0 to 9;
    variable ones   : natural range 0 to 9;
  begin
    number := to_integer(unsigned(value));

    if number >= 10 then
      tens := 1;
      ones := number - 10;
    else
      tens := 0;
      ones := number;
    end if;

    hex_tens <= encode_decimal(tens);
    hex_ones <= encode_decimal(ones);
  end process;

end architecture rtl;