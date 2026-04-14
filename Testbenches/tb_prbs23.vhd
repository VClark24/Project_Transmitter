---------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Testbench Name: PRBS23 Testbench
-- DUT: prbs23.vhd (https://github.com/VClark24/Project_Transmitter/
-- Revisions:
--  V1.0: Created 22/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter) (Adapted from tb_prbs15.vhd)
--  V1.1: 23/01/2026 according to tb_prbs15.vhd changes
-- Comments:
--    MUST run simulation for at least 340 ns
--    Assumes seed consists of all 1's
--    This testbench includes the following tests:
--      1) Synchronous Reset Test (FR-03, FR-10, NFR-01)
--      2) Enable-Gating Test (FR-02, FR-03, FR-10, FR-12, NFR-01, NFR-05)
--      3) Reset Over Enable Priority Test (FR-03, FR-10, NFR-01)
------------------------------------------------------------------------------------------------------------------
-- Same libraries as in prbs23.vhd
library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity prbs23_tb is
end entity prbs23_tb;

architecture testbench of prbs23_tb is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1'; -- LFSR will seed on first clock edge
  signal enable : std_logic := '0'; -- Allows observation of seeded state 
  signal prbs_output : std_logic;
  signal state_dbg : std_logic_vector(22 downto 0); -- Debug port
  
begin
  clk <= not clk after 1 ns; -- Clock generator (500 MHz)
  dut: entity work.prbs23(rtl)
    port map (
      clk => clk,
      reset => reset,
      enable => enable,
      prbs_output => prbs_output,
      state_dbg => state_dbg
    );
   
  stimulus:
  process
    variable ref_bit : std_logic; -- Test 2A
    variable prev_bit : std_logic; -- Test 2B
    variable change_count : natural := 0; -- Test 2B
    variable hold_bit : std_logic; -- Test 2C
    variable new_bit : std_logic; -- Test 2C

    constant expect_len: natural := 64; -- Test 4
    constant expect_64sequence : std_logic_vector(0 to expect_len - 1) :=
  "1111111111111111110000000000000000001111100000000000001111111111"; -- Test 4
    constant ALL_ONE : std_logic_vector(22 downto 0) := (others => '1'); -- Test 4
    
    begin
      -- Test 1: Synchronous Reset
      reset <= '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk); -- Add more if increased simulation clarity is required
      reset <= '0';
      wait until rising_edge(clk);
      assert (prbs_output = '1')
        report "TEST 1 FAILED: PRBS output inconsistent with expected seeded state and therefore synchronous reset was unsuccessful" severity error;
      report "TEST 1 PASSED: Synchronous reset successful" severity note;
  
      -- Test 2: Enable-Gating

      -- Test 2A: Output remains constant when enable low
      enable <= '0';
      change_count := 0;
      wait until rising_edge(clk);
      ref_bit := prbs_output;
      for i in 1 to 16 loop
        wait until rising_edge(clk);
        assert (prbs_output = ref_bit) report "TEST 2A FAILED: Output not constant when enable low" severity error;
      end loop;
      report "TEST 2A PASSED: Output constant when enable low" severity note;

      -- Test 2B: Must advance when enable is high
      enable <= '1';
      wait until rising_edge(clk);
      prev_bit := prbs_output;
      for i in 1 to 64 loop
        wait until rising_edge(clk);
        if prbs_output /= prev_bit then
          change_count := change_count + 1;
        end if;
        prev_bit := prbs_output;
      end loop;
      assert(change_count > 0) report "TEST 2B FAILED: Output fails to advance when enable high" severity error;
      report "TEST 2B PASSED: Output advances when enable high" severity note;

      -- Test 2C: Re-disable enable to ensure that the output freezes immediately
      enable <= '0';
      wait until rising_edge(clk);
      hold_bit := prbs_output;
      for i in 1 to 16 loop
        wait until rising_edge(clk);
        new_bit := prbs_output;
        assert(new_bit = hold_bit) report "TEST 2C FAILED: Output does not freeze immediately once enable is set to low" severity error;
      end loop;
      report "TEST 2C PASSED: Enable behaviour as expected" severity note;
            
      -- Test 3: Reset Priority Over Enable Test 
      reset  <= '1';
      enable <= '1';
      -- 1st clock where reset is sampled
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      -- wait for 0 ns;
      assert state_dbg = ALL_ONE report "TEST 3 FAILED: reset did not force ALL_ONE when enable also high" severity error;
      -- keep reset high another cycle so you can actually SEE it in the waveform
      wait until rising_edge(clk);
      wait for 0 ns;
      assert state_dbg = ALL_ONE report "TEST 3 FAILED: state changed during reset (enable wrongly advancing during reset)" severity error;
      report "TEST 3 PASSED: Reset prioritised over enable" severity note;
      reset <= '0';
      wait until rising_edge(clk);
    wait;
  end process stimulus;
end architecture testbench;
