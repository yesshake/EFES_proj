-- I2S transmitter — serializes 16-bit mono sample into both I2S slots.
-- Clocked on falling BCLK so data is stable before the receiver's rising edge.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.efes_pkg.all;

entity i2s_tx is
  port (
    bclk      : in  std_logic;
    lrclk     : in  std_logic;
    sample_in : in  audio_sample_t;
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
  signal sample_reg   : audio_sample_t := (others => '0');
  signal bit_index    : integer range 0 to AUDIO_SAMPLE_WIDTH-2 := AUDIO_SAMPLE_WIDTH-2;
  signal dac_data_q   : std_logic := '0';

  -- combinational next values
  signal state_next      : tx_state_t;
  signal lrclk_q_next     : std_logic;
  signal sample_reg_next  : audio_sample_t;
  signal bit_index_next   : integer range 0 to AUDIO_SAMPLE_WIDTH-2;
  signal dac_data_next    : std_logic;

begin

  -- state registers (falling-edge BCLK)
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

  -- next-state logic
  comb_proc : process (state, lrclk_q, sample_reg, bit_index,
                        dac_data_q, lrclk, sample_in, valid_in)
  begin

    -- defaults: hold current value
    state_next      <= state;
    lrclk_q_next     <= lrclk_q;
    sample_reg_next  <= sample_reg;
    bit_index_next   <= bit_index;
    dac_data_next    <= dac_data_q;

    case state is

      -- wait for first LRCLK edge
      when SYNC =>

        dac_data_next <= '0';

        if lrclk /= lrclk_q then
            lrclk_q_next <= lrclk;
        
            if valid_in = '1' then
                sample_reg_next <= sample_in;
                dac_data_next   <= sample_in(AUDIO_SAMPLE_WIDTH-1);
            else
                sample_reg_next <= (others => '0');
                dac_data_next   <= '0';
            end if;
          
            bit_index_next <= AUDIO_SAMPLE_WIDTH-2;
            state_next     <= SEND_BITS;
        end if;

      -- output MSB on the first edge after LRCLK transition
      when SEND_MSB =>

        dac_data_next  <= sample_reg(AUDIO_SAMPLE_WIDTH-1);
        bit_index_next <= AUDIO_SAMPLE_WIDTH-2;
        state_next      <= SEND_BITS;

      -- shift out bits 14..0
      when SEND_BITS =>

        dac_data_next <= sample_reg(bit_index);

        if bit_index = 0 then

          -- 16-bit slot: LRCLK might change on the last bit
          if lrclk /= lrclk_q then
            lrclk_q_next <= lrclk;

            if valid_in = '1' then
              sample_reg_next <= sample_in;
            else
              sample_reg_next <= (others => '0');
            end if;

            -- old sample LSB just went out; start the new sample MSB
            if valid_in = '1' then
                sample_reg_next <= sample_in;
                dac_data_next   <= sample_in(AUDIO_SAMPLE_WIDTH-1);
            else
                sample_reg_next <= (others => '0');
                dac_data_next   <= '0';
            end if;
            
            bit_index_next <= AUDIO_SAMPLE_WIDTH-2;
            state_next     <= SEND_BITS;

          else
            -- wider slot: pad with zeros until next LRCLK edge
            state_next <= PAD;
          end if;

        else
          -- early LRCLK: slot shorter than expected, resync
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

      -- zero padding until next slot
      when PAD =>

        dac_data_next <= '0';
          
        if lrclk /= lrclk_q then
            lrclk_q_next <= lrclk;
        
            if valid_in = '1' then
                sample_reg_next <= sample_in;
            
                -- MSB goes out immediately
                dac_data_next <= sample_in(AUDIO_SAMPLE_WIDTH-1);
            else
                sample_reg_next <= (others => '0');
                dac_data_next   <= '0';
            end if;
          
            bit_index_next <= AUDIO_SAMPLE_WIDTH-2;
            state_next     <= SEND_BITS;
        end if;
    end case;
  end process comb_proc;

  dac_data <= dac_data_q;

end architecture rtl;