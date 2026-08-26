-- ================================================================
-- 
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity settings is
  port (
    clk : in std_logic;
    rst_n : in std_logic;

    btn_up : in std_logic;
    btn_down : in std_logic;
    
    btn_mode : in std_logic_vector(2 downto 0);
    btn_save : in std_logic;
    
    mcu_vol : in std_logic_vector(3 downto 0);
    mcu_crush : in std_logic_vector(3 downto 0);
    mcu_down : in std_logic_vector(3 downto 0);
    mcu_rx_valid : in std_logic;
    
    efx_vol : out std_logic_vector(3 downto 0);
    efx_crush : out std_logic_vector(3 downto 0);
    efx_down : out std_logic_vector(3 downto 0);
   
    preset_idx : out std_logic_vector(3 downto 0);
    save_strobe : out std_logic;
    load_strobe : out std_logic
  );
end entity settings;

architecture behavioral of settings is

  signal volume_reg : unsigned(3 downto 0) := (others => '0');
  signal crush_reg  : unsigned(3 downto 0) := (others => '0');
  signal down_reg   : unsigned(3 downto 0) := (others => '0');
  signal preset_reg : unsigned(3 downto 0) := (others => '0');

  signal up_previous     : std_logic := '1';
  signal down_previous   : std_logic := '1';
  signal action_previous : std_logic := '1';

  signal save_strobe_reg : std_logic := '0';
  signal load_strobe_reg : std_logic := '0';

begin

  efx_vol     <= std_logic_vector(volume_reg);
  efx_crush   <= std_logic_vector(crush_reg);
  efx_down    <= std_logic_vector(down_reg);
  preset_idx  <= std_logic_vector(preset_reg);

  save_strobe <= save_strobe_reg;
  load_strobe <= load_strobe_reg;

  process (clk, rst_n)
    variable up_pressed     : boolean;
    variable down_pressed   : boolean;
    variable action_pressed : boolean;
  begin
    if rst_n = '0' then
      volume_reg <= (others => '0');
      crush_reg  <= (others => '0');
      down_reg   <= (others => '0');
      preset_reg <= (others => '0');

      up_previous     <= '1';
      down_previous   <= '1';
      action_previous <= '1';

      save_strobe_reg <= '0';
      load_strobe_reg <= '0';

    elsif rising_edge(clk) then

      up_pressed := (up_previous = '1') and (btn_up = '0');
      down_pressed := (down_previous = '1') and (btn_down = '0');
      action_pressed := (action_previous = '1') and (btn_save = '0');

      up_previous     <= btn_up;
      down_previous   <= btn_down;
      action_previous <= btn_save;

      save_strobe_reg <= '0';
      load_strobe_reg <= '0';

      -- Future loaded preset from the STM32
      if mcu_rx_valid = '1' then
        volume_reg <= unsigned(mcu_vol);
        crush_reg  <= unsigned(mcu_crush);
        down_reg   <= unsigned(mcu_down);
      else
        if up_pressed and not down_pressed then
          case btn_mode is
            when "000" =>
              if volume_reg /= 15 then
                volume_reg <= volume_reg + 1;
              end if;
            when "001" =>
              if crush_reg /= 15 then
                crush_reg <= crush_reg + 1;
              end if;
            when "010" =>
              if down_reg /= 15 then
                down_reg <= down_reg + 1;
              end if;
            when "011" =>
              if preset_reg /= 15 then
                preset_reg <= preset_reg + 1;
              end if;
            when others =>
              null;
          end case;
        elsif down_pressed and not up_pressed then
          case btn_mode is
            when "000" =>
              if volume_reg /= 0 then
                volume_reg <= volume_reg - 1;
              end if;
            when "001" =>
              if crush_reg /= 0 then
                crush_reg <= crush_reg - 1;
              end if;
            when "010" =>
              if down_reg /= 0 then
                down_reg <= down_reg - 1;
              end if;
            when "011" =>
              if preset_reg /= 0 then
                preset_reg <= preset_reg - 1;
              end if;
            when others =>
              null;
          end case;
        end if;

        if action_pressed then
          if btn_mode = "100" then
            save_strobe_reg <= '1';
          elsif btn_mode = "101" then
            load_strobe_reg <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture behavioral;