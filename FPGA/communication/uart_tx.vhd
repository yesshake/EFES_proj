library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.efes_pkg.all;

entity uart_tx is
  generic (
    CLK_FREQ : integer := 50000000;
    BAUD_RATE : integer := 115200
  );
  port (
    clk : in std_logic;
    rst_n : in std_logic;

    tx_data : in uart_byte_t;
    tx_start : in std_logic;

    tx_busy : out std_logic;
    tx_line : out std_logic
  );
end entity uart_tx;

architecture Behavioral of uart_tx is

  constant CLKS_PER_BIT : positive := (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;

  type state_t is (
    IDLE,
    START_BIT,
    DATA_BITS,
    STOP_BIT
  );

  signal state : state_t := IDLE;

  signal clock_count : natural range 0 to CLKS_PER_BIT - 1 := 0;
  signal bit_index   : natural range 0 to 7 := 0;
  signal data_reg    : uart_byte_t := (others => '0');

  signal tx_reg      : std_logic := '1';
  signal busy_reg    : std_logic := '0';

begin

  tx_line <= tx_reg;
  tx_busy <= busy_reg;

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      state       <= IDLE;
      clock_count <= 0;
      bit_index   <= 0;
      data_reg    <= (others => '0');
      tx_reg      <= '1';
      busy_reg    <= '0';
    elsif rising_edge(clk) then
      case state is
        when IDLE =>
          tx_reg      <= '1';
          busy_reg    <= '0';
          clock_count <= 0;
          bit_index   <= 0;

          if tx_start = '1' then
            data_reg <= tx_data;
            tx_reg   <= '0';
            busy_reg <= '1';
            state    <= START_BIT;
          end if;

        when START_BIT =>
          if clock_count = CLKS_PER_BIT - 1 then
            clock_count <= 0;
            bit_index   <= 0;
            tx_reg      <= data_reg(0);
            state       <= DATA_BITS;
          else
            clock_count <= clock_count + 1;
          end if;

        when DATA_BITS =>
          if clock_count = CLKS_PER_BIT - 1 then
            clock_count <= 0;
            if bit_index = 7 then
              tx_reg <= '1';
              state  <= STOP_BIT;
            else
              bit_index <= bit_index + 1;
              tx_reg    <= data_reg(bit_index + 1);
            end if;
          else
            clock_count <= clock_count + 1;
          end if;

        when STOP_BIT =>
          if clock_count = CLKS_PER_BIT - 1 then
            clock_count <= 0;
            tx_reg      <= '1';
            busy_reg    <= '0';
            state       <= IDLE;
          else
            clock_count <= clock_count + 1;
          end if;
      end case;
    end if;
  end process;

end architecture Behavioral;
