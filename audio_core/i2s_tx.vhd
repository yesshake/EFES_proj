-- ================================================================
-- I2S transmitter module
-- ================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_tx is
  port (
    bclk      : in  std_logic;
    lrclk     : in  std_logic;
    sample_in : in  std_logic_vector(15 downto 0);
    dac_data  : out std_logic;

    -- Internal FPGA valid logic
    valid_in  : in  std_logic
  );
end entity i2s_tx;

architecture rtl of i2s_tx is

  type tx_state_t is (
    SYNC,       -- Wait for the first LRCLK transition
    SEND_MSB,   -- Send bit 15 after the I2S delay
    SEND_BITS,  -- Send bits 14 down to 0
    PAD         -- Output zero until the next LRCLK transition
  );

  -- registered current values
  signal state        : tx_state_t := SYNC;
  signal lrclk_q      : std_logic := '0';
  signal sample_reg   : std_logic_vector(15 downto 0) := (others => '0');
  signal bit_index    : integer range 0 to 14 := 14;
  signal dac_data_q   : std_logic := '0';

  -- combinational next values
  signal state_next      : tx_state_t;
  signal lrclk_q_next     : std_logic;
  signal sample_reg_next  : std_logic_vector(15 downto 0);
  signal bit_index_next   : integer range 0 to 14;
  signal dac_data_next    : std_logic;

begin

  ----------------------------------------------------------------
  -- Register process: sole clocked process, no combinational
  -- logic other than passing *_next signals through to state.
  ----------------------------------------------------------------
  reg_proc : process (bclk)
  begin
    if falling_edge(bclk) then
      state      <= state_next;
      lrclk_q    <= lrclk_q_next;
      sample_reg <= sample_reg_next;
      bit_index  <= bit_index_next;
      dac_data_q <= dac_data_next;
    end if;
  end process reg_proc;

  ----------------------------------------------------------------
  -- Combinational process: computes next state/outputs from the
  -- current state and inputs. No clock, no reset here.
  ----------------------------------------------------------------
  comb_proc : process (state, lrclk_q, sample_reg, bit_index,
                        dac_data_q, lrclk, sample_in, valid_in)
  begin

    -- Defaults: hold current value unless overridden below.
    state_next      <= state;
    lrclk_q_next     <= lrclk_q;
    sample_reg_next  <= sample_reg;
    bit_index_next   <= bit_index;
    dac_data_next    <= dac_data_q;

    case state is

      ----------------------------------------------------------------
      -- Wait for synchronization with LRCLK.
      ----------------------------------------------------------------
      when SYNC =>

        dac_data_next <= '0';

        if lrclk /= lrclk_q then
          lrclk_q_next <= lrclk;

          -- Capture the parallel sample for the slot about to start.
          if valid_in = '1' then
            sample_reg_next <= sample_in;
          else
            sample_reg_next <= (others => '0');
          end if;

          -- This falling edge represents the I2S delay position.
          -- The MSB is transmitted on the next falling edge.
          state_next <= SEND_MSB;
        end if;

      ----------------------------------------------------------------
      -- First falling edge after the LRCLK transition.
      ----------------------------------------------------------------
      when SEND_MSB =>

        dac_data_next  <= sample_reg(15);
        bit_index_next <= 14;
        state_next      <= SEND_BITS;

      ----------------------------------------------------------------
      -- Transmit bits 14 down to 0.
      ----------------------------------------------------------------
      when SEND_BITS =>

        dac_data_next <= sample_reg(bit_index);

        if bit_index = 0 then

          -- With a 16-bit slot, LRCLK may change while the LSB is
          -- being transmitted.
          if lrclk /= lrclk_q then
            lrclk_q_next <= lrclk;

            if valid_in = '1' then
              sample_reg_next <= sample_in;
            else
              sample_reg_next <= (others => '0');
            end if;

            -- The current edge transmitted the old sample LSB.
            -- The next edge transmits the new sample MSB.
            state_next <= SEND_MSB;

          else
            -- Wider slot: output padding until LRCLK changes.
            state_next <= PAD;
          end if;

        else
          -- An early LRCLK transition means the external slot is
          -- shorter than expected. Resynchronize to the new slot.
          if lrclk /= lrclk_q then
            lrclk_q_next <= lrclk;

            if valid_in = '1' then
              sample_reg_next <= sample_in;
            else
              sample_reg_next <= (others => '0');
            end if;

            state_next <= SEND_MSB;

          else
            bit_index_next <= bit_index - 1;
          end if;
        end if;

      ----------------------------------------------------------------
      -- Send zero padding until the next slot begins.
      ----------------------------------------------------------------
      when PAD =>

        dac_data_next <= '0';

        if lrclk /= lrclk_q then
          lrclk_q_next <= lrclk;

          if valid_in = '1' then
            sample_reg_next <= sample_in;
          else
            sample_reg_next <= (others => '0');
          end if;

          -- Current edge is the I2S delay position.
          state_next <= SEND_MSB;
        end if;

    end case;
  end process comb_proc;

  -- Output
  dac_data <= dac_data_q;

end architecture rtl;