-- ================================================================
-- I2S receiver
--
-- Receives 16-bit standard-I2S samples from the WM8731.
--
-- Assumptions:
--   * WM8731 generates BCLK and LRCLK.
--   * Serial data is sampled on the rising edge of BCLK.
--   * LRCLK changes one BCLK period before the next sample MSB.
--   * Slots may be wider than 16 bits; extra bits are ignored.
--
-- A one-BCLK-cycle valid pulse is generated after every received
-- 16-bit sample.
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;

entity i2s_rx is
  port (
    bclk       : in  std_logic;
    lrclk      : in  std_logic;
    adc_dat    : in  std_logic;
    sample_out : out std_logic_vector(15 downto 0);
    valid      : out std_logic
  );
end entity i2s_rx;


architecture rtl of i2s_rx is

  type state_t is (
    SYNC_LRCLK,
    WAIT_LRCLK_EDGE,
    WAIT_MSB,
    RECEIVE_BITS
  );

  signal state : state_t := SYNC_LRCLK;

  signal previous_lrclk : std_logic := '0';

  signal shift_reg :
    std_logic_vector(15 downto 0) := (others => '0');

  signal sample_reg :
    std_logic_vector(15 downto 0) := (others => '0');

  signal bit_index :
    natural range 0 to 15 := 15;

  signal valid_reg : std_logic := '0';

begin

  sample_out <= sample_reg;
  valid      <= valid_reg;


  process (bclk)
  begin
    if rising_edge(bclk) then

      -- valid is asserted for only one BCLK cycle.
      valid_reg <= '0';

      case state is

        ------------------------------------------------------------
        -- Capture the initial LRCLK level.
        ------------------------------------------------------------
        when SYNC_LRCLK =>
          previous_lrclk <= lrclk;
          state          <= WAIT_LRCLK_EDGE;


        ------------------------------------------------------------
        -- Wait for the beginning of either the left or right slot.
        ------------------------------------------------------------
        when WAIT_LRCLK_EDGE =>
          if lrclk /= previous_lrclk then
            previous_lrclk <= lrclk;
            bit_index      <= 15;
            state          <= WAIT_MSB;
          end if;


        ------------------------------------------------------------
        -- Standard I2S inserts one BCLK delay between the LRCLK
        -- transition and the sample MSB.
        --
        -- The LRCLK transition was detected on the preceding rising
        -- edge. The MSB is captured on this rising edge.
        ------------------------------------------------------------
        when WAIT_MSB =>
          shift_reg(15) <= adc_dat;
          bit_index     <= 14;
          state         <= RECEIVE_BITS;


        ------------------------------------------------------------
        -- Receive the remaining 15 sample bits, MSB first.
        ------------------------------------------------------------
        when RECEIVE_BITS =>
          shift_reg(bit_index) <= adc_dat;

          if bit_index = 0 then

            -- Include adc_dat directly because the signal assignment
            -- to shift_reg(0) takes effect after this process.
            sample_reg <= shift_reg(15 downto 1) & adc_dat;
            valid_reg  <= '1';

            state <= WAIT_LRCLK_EDGE;

          else
            bit_index <= bit_index - 1;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;