-- ================================================================
-- 
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_setting_interface is
  port (
    clk   : in std_logic;
    rst_n : in std_logic;

    rx_data  : in std_logic_vector(7 downto 0);
    rx_valid : in std_logic;

    save_strobe   : in std_logic;
    load_strobe   : in std_logic;
    preset_idx_in : in std_logic_vector(3 downto 0);

    efx_vol_in   : in std_logic_vector(3 downto 0);
    efx_crush_in : in std_logic_vector(3 downto 0);
    efx_down_in  : in std_logic_vector(3 downto 0);

    tx_data  : out std_logic_vector(7 downto 0);
    tx_start : out std_logic;
    tx_busy  : in std_logic;

    mcu_vol_out   : out std_logic_vector(3 downto 0);
    mcu_crush_out : out std_logic_vector(3 downto 0);
    mcu_down_out  : out std_logic_vector(3 downto 0);
    mcu_rx_valid  : out std_logic
  );
end entity UART_setting_interface;

architecture Behavioral of UART_setting_interface is

  constant CMD_SAVE_PRESET : std_logic_vector(7 downto 0) := x"10";
  constant CMD_LOAD_PRESET : std_logic_vector(7 downto 0) := x"11";

  type state_t is (
    IDLE,
    PRESENT_BYTE,
    WAIT_BUSY_HIGH,
    WAIT_BUSY_LOW
  );

  type frame_type_t is (
    SAVE_FRAME,
    LOAD_FRAME
  );

  signal state      : state_t := IDLE;
  signal frame_type : frame_type_t := SAVE_FRAME;

  signal byte_index : natural range 0 to 4 := 0;
  signal last_index : natural range 1 to 4 := 1;

  signal preset_reg : std_logic_vector(3 downto 0);
  signal volume_reg : std_logic_vector(3 downto 0);
  signal crush_reg  : std_logic_vector(3 downto 0);
  signal down_reg   : std_logic_vector(3 downto 0);

  signal tx_data_reg  : std_logic_vector(7 downto 0);
  signal tx_start_reg : std_logic := '0';

begin

  tx_data  <= tx_data_reg;
  tx_start <= tx_start_reg;

  -- UART receive is not implemented yet
  mcu_vol_out   <= (others => '0');
  mcu_crush_out <= (others => '0');
  mcu_down_out  <= (others => '0');
  mcu_rx_valid  <= '0';

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      state        <= IDLE;
      frame_type   <= SAVE_FRAME;
      byte_index   <= 0;
      last_index   <= 1;

      preset_reg <= (others => '0');
      volume_reg <= (others => '0');
      crush_reg  <= (others => '0');
      down_reg   <= (others => '0');

      tx_data_reg  <= (others => '0');
      tx_start_reg <= '0';

    elsif rising_edge(clk) then
      tx_start_reg <= '0';

      case state is
        when IDLE =>
          if save_strobe = '1' then
            frame_type <= SAVE_FRAME;
            byte_index <= 0;
            last_index <= 4;

            -- Snapshot the complete request
            preset_reg <= preset_idx_in;
            volume_reg <= efx_vol_in;
            crush_reg  <= efx_crush_in;
            down_reg   <= efx_down_in;

            state <= PRESENT_BYTE;

          elsif load_strobe = '1' then
            frame_type <= LOAD_FRAME;
            byte_index <= 0;
            last_index <= 1;
            preset_reg <= preset_idx_in;

            state <= PRESENT_BYTE;
          end if;

        when PRESENT_BYTE =>
          if tx_busy = '0' then
            case byte_index is
              when 0 =>
                if frame_type = SAVE_FRAME then
                  tx_data_reg <= CMD_SAVE_PRESET;
                else
                  tx_data_reg <= CMD_LOAD_PRESET;
                end if;

              when 1 =>
                tx_data_reg <= "0000" & preset_reg;

              when 2 =>
                tx_data_reg <= "0000" & volume_reg;

              when 3 =>
                tx_data_reg <= "0000" & crush_reg;

              when others =>
                tx_data_reg <= "0000" & down_reg;
            end case;

            tx_start_reg <= '1';
            state        <= WAIT_BUSY_HIGH;
          end if;

        when WAIT_BUSY_HIGH =>
          if tx_busy = '1' then
            state <= WAIT_BUSY_LOW;
          end if;

        when WAIT_BUSY_LOW =>
          if tx_busy = '0' then
            if byte_index = last_index then
              state <= IDLE;
            else
              byte_index <= byte_index + 1;
              state      <= PRESENT_BYTE;
            end if;
          end if;
      end case;
    end if;
  end process;

end architecture Behavioral;