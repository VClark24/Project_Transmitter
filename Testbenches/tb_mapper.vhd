-----------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Testbench Name: Modulaion Mapper Testbench
-- DUT: mapper.vhd (https://github.com/VClark24/Project_Transmitter/blob/feature/mod_integration/vhdl/modulation/mapper.vhd)
-- Revisions:
--  V1.0: Created 26/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--  Testbench MUST be run for at least 45 ns
--  1) Synchronous Reset Test
--  2) BPSK Output Test
--  3) OQPSK Output Test
---------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity mapper_tb is 
end entity mapper_tb;

architecture testbench of mapper_tb is
    constant G_WIDTH : integer := 16;
    constant ZERO_I : signed(G_WIDTH-1 downto 0) := (others => '0');
    constant ZERO_Q : signed(G_WIDTH-1 downto 0) := (others => '0');
    constant AMP_POS : signed(G_WIDTH-1 downto 0) := to_signed((2**(G_WIDTH-1))-1, G_WIDTH);
    constant AMP_NEG : signed(G_WIDTH-1 downto 0) := to_signed(-(2**(G_WIDTH-1)),  G_WIDTH);
    constant ZERO    : signed(G_WIDTH-1 downto 0) := (others => '0');
    
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal enable : std_logic := '1';
    signal symbol_en : std_logic := '0'; -- symbol strobe
    signal half_symbol_en : std_logic := '0'; --half-symbol strobe
    signal prbs_in : std_logic := '0';
    signal i_out : signed(G_WIDTH-1 downto 0) := (others => '0');
    signal q_out : signed(G_WIDTH-1 downto 0) := (others => '0');
    signal waveform_sel : unsigned(2 downto 0) := "011"; -- Beacon default

    begin
      clk <= not clk after 1 ns; -- Clock generator (500 MHz) 
      dut: entity work.mapper(rtl)
      port map (
        clk => clk,
        reset => reset,
        enable => enable,
        symbol_en => symbol_en,
        half_symbol_en => half_symbol_en,
        prbs_in => prbs_in,
        i_out => i_out,
        q_out => q_out,
        waveform_sel => waveform_sel
        );

      stimulus:
      process
        variable prev_i : signed(G_WIDTH-1 downto 0);
        variable prev_q : signed(G_WIDTH-1 downto 0);
        begin
          -- Test 1: Synchronous Reset Test
          
          reset <= '1';
          wait until rising_edge(clk);
          wait until rising_edge(clk);
          reset <= '0';
          wait until rising_edge(clk);
          assert (i_out = ZERO_I and q_out = ZERO_Q) report "TEST 1 FAILED: Synchronous reset unsuccessful" severity failure;
          report "TEST 1 PASSED: Synchronous reset functions as expected" severity note;

          -- Test 2: BPSK Output Test (I and Q)
                  
          -- Telecommand
          waveform_sel <= "000";
          half_symbol_en <= '0';
          wait until rising_edge(clk);
          prbs_in <= '0';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_NEG) report "TEST 2 FAILED: BPSK i_out fail for Telecommand waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Telecommand waveform" severity failure;
          wait until rising_edge(clk);
          prbs_in <= '1';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_POS) report "TEST 2 FAILED: BPSK i_out fail for Telecommand waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Telecommand waveform" severity failure;
          report "TEST 2 PASSED: BPSK successful for Telecommand waveform" severity note;

          -- Telemetry (Category B)
          waveform_sel <= "010";
          half_symbol_en <= '0';
          wait until rising_edge(clk);
          prbs_in <= '0';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_NEG) report "TEST 2 FAILED: BPSK i_out fail for Telemetry (Category B) waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Telemetry (Category B) waveform" severity failure;
          wait until rising_edge(clk);
          prbs_in <= '1';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_POS) report "TEST 2 FAILED: BPSK i_out fail for Telemetry (Category B) waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Telemtry (Category B) waveform" severity failure;
          report "TEST 2 PASSED: BPSK successful for Telemetry (Category B) waveform" severity note;

          -- Beacon
          waveform_sel <= "011";
          half_symbol_en <= '0';
          wait until rising_edge(clk);
          prbs_in <= '0';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_NEG) report "TEST 2 FAILED: BPSK i_out fail for Beacon waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Beacon waveform" severity failure;
          wait until rising_edge(clk);
          prbs_in <= '1';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_POS) report "TEST 2 FAILED: BPSK i_out fail for Beacon waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for Beacon waveform" severity failure;
          report "TEST 2 PASSED: BPSK successful for Beacon waveform" severity note;

          -- FHSS
          waveform_sel <= "100";
          half_symbol_en <= '0';
          wait until rising_edge(clk);
          prbs_in <= '0';
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_NEG) report "TEST 2 FAILED: BPSK i_out fail for FHSS waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for FHSS waveform" severity failure;
          prbs_in <= '1';
          wait until rising_edge(clk);
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          wait for 0 ns; --optional delta cycle
          assert (i_out = AMP_POS) report "TEST 2 FAILED: BPSK i_out fail for FHSS waveform" severity failure;
          assert (q_out = ZERO_Q) report "TEST 2 FAILED: BPSK q_out fail for FHSS waveform" severity failure;
          report "TEST 2 PASSED: BPSK successful for FHSS waveform" severity note;

          -- Test 3: OQPSK (I and Q) Output Test

          waveform_sel <= "001"; -- Telemetry (Category A)
          half_symbol_en <= '0';
          symbol_en <= '0';
          enable <= '1';
          wait until rising_edge(clk);
          prbs_in <= '0'; -- I = -FS
          prev_q := q_out;
          symbol_en <= '1';
          wait until rising_edge(clk);
          symbol_en <= '0';
          half_symbol_en <= '0';
          wait for 0 ns;
          assert (i_out = AMP_NEG) report "TEST 3 FAILED: I not updated on symbol_en (OQPSK)" severity failure;
          assert (q_out = prev_q) report "TEST 3 FAILED: Q changed on symbol_en (OQPSK)" severity failure;
          prbs_in <= '1'; -- Q = +FS
          prev_i := i_out;
          half_symbol_en <= '1';
          wait until rising_edge(clk);
          half_symbol_en <= '0';
          wait for 0 ns;
          assert (q_out = AMP_POS) report "TEST 3 FAILED: Q not updated on half_symbol_en" severity failure;
          assert (i_out = prev_i) report "TEST 3 FAILED: I changed on half_symbol_en" severity failure;
          prev_i := i_out;
          prev_q := q_out;
          wait until rising_edge(clk);
          wait for 0 ns;
          assert (i_out = prev_i and q_out = prev_q) report "TEST 3 FAILED: Outputs changed without strobe" severity failure;
          report "TEST 3 PASSED: of OQPSK performs as expected" severity note;
          report "ALL TESTS PASSED" severity note;
          wait;
        end process;
end architecture;

