library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.efes_pkg.all;

entity uart_rx is
  generic (
    CLK_FREQ_HZ : positive := 50_000_000;
    BAUD_RATE    : positive := 115_200
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    uart_rx_i  : in  std_logic;
    data_out   : out uart_byte_t;
    data_valid : out std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is

  constant CLKS_PER_BIT : positive  := (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
  constant HALF_BIT_COUNT : natural := (CLKS_PER_BIT - 1) / 2;

  type state_t is (
    IDLE,
    START_BIT,
    DATA_BITS,
    STOP_BIT
  );

  signal state       : state_t := IDLE;
  signal clock_count : natural range 0 to CLKS_PER_BIT - 1 := 0;
  signal bit_index   : natural range 0 to 7 := 0;
  signal data_reg    : uart_byte_t := (others => '0');

  -- Synchronize the asynchronous UART input
  signal rx_meta : std_logic := '1';
  signal rx_sync : std_logic := '1';

begin

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      rx_meta <= '1';
      rx_sync <= '1';

    elsif rising_edge(clk) then
      rx_meta <= uart_rx_i;
      rx_sync <= rx_meta;
    end if;
  end process;

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      state       <= IDLE;
      clock_count <= 0;
      bit_index   <= 0;
      data_reg    <= (others => '0');
      data_out    <= (others => '0');
      data_valid  <= '0';

    elsif rising_edge(clk) then
      data_valid <= '0';

      case state is

        when IDLE =>
          clock_count <= 0;
          bit_index   <= 0;

          if rx_sync = '0' then
            state <= START_BIT;
          end if;

        when START_BIT =>
          -- Check the start bit near its centre
          if clock_count = HALF_BIT_COUNT then
            clock_count <= 0;

            if rx_sync = '0' then
              state <= DATA_BITS;
            else
              -- False start bit.
              state <= IDLE;
            end if;
          else
            clock_count <= clock_count + 1;
          end if;

        when DATA_BITS =>
          if clock_count = CLKS_PER_BIT - 1 then
            clock_count         <= 0;
            data_reg(bit_index) <= rx_sync;

            if bit_index = 7 then
              bit_index <= 0;
              state     <= STOP_BIT;
            else
              bit_index <= bit_index + 1;
            end if;
          else
            clock_count <= clock_count + 1;
          end if;

        when STOP_BIT =>
          if clock_count = CLKS_PER_BIT - 1 then
            clock_count <= 0;
            state       <= IDLE;

            -- Only accept a valid high stop bit.
            if rx_sync = '1' then
              data_out   <= data_reg;
              data_valid <= '1';
            end if;
          else
            clock_count <= clock_count + 1;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;