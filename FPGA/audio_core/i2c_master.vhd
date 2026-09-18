-- WM8731 I2C configuration controller
-- Sends the startup register sequence from wm8731_pkg
-- Each config word is a 3 byte I2C write: START, address, high byte, low byte, STOP

library ieee;
use ieee.std_logic_1164.all;

use work.wm8731_pkg.all;

entity i2c_master is
  generic (
    CLK_FREQ_HZ      : positive := 50_000_000;
    I2C_FREQ_HZ      : positive := 100_000;
    STARTUP_DELAY_MS : positive := 10
  );
  port (
    clk       : in    std_logic;
    rst_n     : in    std_logic;
	 
	 -- I2C interfaces
    i2c_sclk  : inout std_logic;
    i2c_sdat  : inout std_logic;
	 
	 -- Status ports for higher level 
    done      : out   std_logic;	
    ack_error : out   std_logic
  );
end entity i2c_master;

architecture rtl of i2c_master is
  -- floor to 1 for counter bounds
  function max_one(value : natural) return positive is
  begin
    if value = 0 then
      return 1;
    end if;
    return value;
  end function;

  -- quarter period of one SCL cycle, in system clock ticks
  constant QUARTER_CYCLES : positive := max_one(CLK_FREQ_HZ / (4 * I2C_FREQ_HZ));

  -- startup delay in quarter period ticks
  constant STARTUP_TICKS : positive := max_one((4 * I2C_FREQ_HZ * STARTUP_DELAY_MS) / 1000);

  type state_t is (
    STARTUP,
    START_CONDITION,
    SEND_BYTE,
    RECEIVE_ACK,
    STOP_CONDITION,
    NEXT_REGISTER,
    FINISHED,
    ERROR_STATE
  );

  signal state : state_t := STARTUP;

  signal divider_count : natural range 0 to QUARTER_CYCLES - 1 := 0;
  signal startup_count : natural range 0 to STARTUP_TICKS - 1 := 0;

  -- SCL phase within one bit period
  signal phase : natural range 0 to 3 := 0;

  signal config_index : natural range 0 to WM8731_CONFIG_WORDS'length - 1 := 0;
  signal byte_index   : natural range 0 to 2 := 0;
  signal bit_index    : natural range 0 to 7 := 7;

  signal tx_byte : std_logic_vector(7 downto 0) := WM8731_WRITE_BYTE;

  -- open-drain: '1' = pull low, '0' = release (pulled up externally)
  signal scl_drive_low : std_logic := '0';
  signal sda_drive_low : std_logic := '0';

  signal ack_received  : std_logic := '0';
  signal error_pending : std_logic := '0';

  signal done_reg      : std_logic := '0';
  signal ack_error_reg : std_logic := '0';

begin

  -- open-drain driving
  i2c_sclk <= '0' when scl_drive_low = '1' else 'Z';
  i2c_sdat <= '0' when sda_drive_low = '1' else 'Z';

  done      <= done_reg;
  ack_error <= ack_error_reg;

  process (clk, rst_n)
  begin
    if rst_n = '0' then
      state <= STARTUP;

      divider_count <= 0;
      startup_count <= 0;
      phase         <= 0;

      config_index <= 0;
      byte_index   <= 0;
      bit_index    <= 7;
      tx_byte      <= WM8731_WRITE_BYTE; -- I2C address byte of wm8731

      scl_drive_low <= '0';
      sda_drive_low <= '0';
      ack_received  <= '0';
      error_pending <= '0';

      done_reg      <= '0';
      ack_error_reg <= '0';

    elsif rising_edge(clk) then
      if divider_count = QUARTER_CYCLES - 1 then
        divider_count <= 0;

        case state is

          when STARTUP =>
            scl_drive_low <= '0';
            sda_drive_low <= '0';
            done_reg      <= '0';
            ack_error_reg <= '0';
            error_pending <= '0';
            if startup_count = STARTUP_TICKS - 1 then
              startup_count <= 0;
              config_index  <= 0;
              phase         <= 0;
              state         <= START_CONDITION;
            else
              startup_count <= startup_count + 1;
            end if;

          when START_CONDITION =>
            case phase is
              when 0 =>
                -- release both lines
                scl_drive_low <= '0';
                sda_drive_low <= '0';
                phase         <= 1;

              when 1 =>
                -- START condition: SDA falls while SCL high
                scl_drive_low <= '0';
                sda_drive_low <= '1';
                phase         <= 2;

              when 2 =>
                -- pull SCL low before data bits
                scl_drive_low <= '1';
                sda_drive_low <= '1';
                phase         <= 3;

              when others =>
                -- load address byte and start sending
                byte_index <= 0;
                bit_index  <= 7;
                tx_byte    <= WM8731_WRITE_BYTE;
                phase      <= 0;
                state      <= SEND_BYTE;
            end case;

          when SEND_BYTE =>
            case phase is
              when 0 =>
                -- set SDA while SCL is low
                scl_drive_low <= '1';

                if tx_byte(bit_index) = '0' then
                  sda_drive_low <= '1';
                else
                  sda_drive_low <= '0';
                end if;

                phase <= 1;

              when 1 =>
                -- release SCL; target samples the bit
                scl_drive_low <= '0';
                phase         <= 2;

              when 2 =>
                -- SDA held during SCL high
                scl_drive_low <= '0';
                phase         <= 3;

              when others =>
                -- pull SCL low to end the bit
                scl_drive_low <= '1';
                phase         <= 0;
                 -- byte done, expect ACK
                if bit_index = 0 then
                  state <= RECEIVE_ACK;
                else
                  bit_index <= bit_index - 1;
                end if;
            end case;

          when RECEIVE_ACK =>
            case phase is
              when 0 =>
                -- release SDA so codec can ACK
                scl_drive_low <= '1';
                sda_drive_low <= '0';
                ack_received  <= '0';
                phase         <= 1;

              when 1 =>
                -- release SCL for ACK
                scl_drive_low <= '0';
                phase         <= 2;

              when 2 =>
                -- sample ACK (active-low)
                scl_drive_low <= '0';

                if i2c_sdat = '0' then
                  ack_received <= '1';
                else
                  ack_received <= '0';
                end if;

                phase <= 3;

              when others =>
                scl_drive_low <= '1';
                sda_drive_low <= '0';
                phase         <= 0;

                if ack_received = '0' then
                  error_pending <= '1';
                  state         <= STOP_CONDITION;

                elsif byte_index = 0 then
                  byte_index <= 1;
                  bit_index  <= 7;
                  tx_byte    <= WM8731_CONFIG_WORDS(config_index)(15 downto 8);
                  state      <= SEND_BYTE;

                elsif byte_index = 1 then
                  byte_index <= 2;
                  bit_index  <= 7;
                  tx_byte    <= WM8731_CONFIG_WORDS(config_index)(7 downto 0);
                  state      <= SEND_BYTE;

                else
                  error_pending <= '0';
                  state         <= STOP_CONDITION;
                end if;
            end case;

          when STOP_CONDITION =>
            case phase is
              when 0 =>
                -- SDA and SCL low before STOP
                scl_drive_low <= '1';
                sda_drive_low <= '1';
                phase         <= 1;

              when 1 =>
                -- release SCL, keep SDA low
                scl_drive_low <= '0';
                sda_drive_low <= '1';
                phase         <= 2;

              when 2 =>
                -- release SDA while SCL high = STOP condition
                scl_drive_low <= '0';
                sda_drive_low <= '0';
                phase         <= 3;

              when others =>
                scl_drive_low <= '0';
                sda_drive_low <= '0';
                phase         <= 0;

                if error_pending = '1' then
                  state <= ERROR_STATE;
                else
                  state <= NEXT_REGISTER;
                end if;
            end case;

          when NEXT_REGISTER =>
            scl_drive_low <= '0';
            sda_drive_low <= '0';

            if config_index = WM8731_CONFIG_WORDS'length - 1 then
              state <= FINISHED;
            else
              config_index <= config_index + 1;
              phase        <= 0;
              state        <= START_CONDITION;
            end if;

          when FINISHED =>
            scl_drive_low <= '0';
            sda_drive_low <= '0';
            done_reg      <= '1';
            ack_error_reg <= '0';

          when ERROR_STATE =>
            scl_drive_low <= '0';
            sda_drive_low <= '0';
            done_reg      <= '0';
            ack_error_reg <= '1';

        end case;

      else
        divider_count <= divider_count + 1;
      end if;
    end if;
  end process;

end architecture rtl;