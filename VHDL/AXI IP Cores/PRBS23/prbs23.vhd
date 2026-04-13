-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: PRBS23
-- Revisions:
--  V1.0: Created 21/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--  LFSR Architecture: Galois
--  Shift Direction: Right-Shift (Towards LSB)
--  Output Bit: LSB
--  Output Timing: Output-Before-Update
--  Reset Timing: Synchronous
--  Seed: Fixed, Non-Zero
--  Enable Behaviour: Enable-Gated (to be integrated into AXI IP later)
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity prbs23 is
  port(
    clk : in std_logic;
    reset : in std_logic; -- Permits synchronous reset, active-high
    enable : in std_logic; -- Enables state advance (enable-gating and not clock gating)
    prbs_output : out std_logic; -- Current PRBS output bit (LSB, pre-update)
    state_dbg : out std_logic_vector(22 downto 0) -- Debug port
  );
end entity prbs23;

architecture rtl of prbs23 is
    constant seed : std_logic_vector(22 downto 0) := (others => '1') ; -- Must NOT be all zeros (will cause LFSR lock-up), all ones here to ensure deterministic and repeatable behaviour
    constant tap_mask : std_logic_vector(22 downto 0) := std_logic_vector(to_unsigned(16#420000#, 23)); -- PRBS23, polynomial x^23 + x^18 + 1 (right-shift Galois)
    signal lfsr_state : std_logic_vector(22 downto 0) := seed; -- PRBS order = register length, initialises to seed for simulation clarity and reset to enforce seed in hardware
    
begin
    prbs_output <= lfsr_state(0); -- LSB output bit, output-before-update so concurrent assignment
    state_dbg <= lfsr_state;
    process(clk)
      variable feedback_bit : std_logic; -- In Galois architecture, the value of this bit determines whether feedback taps are XOR'd into the shifted state
      variable next_state : std_logic_vector(22 downto 0);
      begin
        if rising_edge(clk) then
          if reset = '1' then
            lfsr_state <= seed; -- Resets LFSR to seed value
          elsif enable = '1' then
            feedback_bit := lfsr_state(0); -- Captures feedback bit
            next_state := '0' & lfsr_state(22 downto 1); -- Performs right-shift
            if feedback_bit = '1' then
              next_state := next_state xor tap_mask; -- XOR gate
            end if;
            lfsr_state <= next_state; -- New state assgined, since lfsr_state is a signal, it will only update after the process finishes. Old state is still visible
          end if;
        end if;
    end process;
end architecture rtl; 
