-----------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Testbench Name: Symbol Timer Testbench
-- DUT: symbol_timing.vhd (https://github.com/VClark24/Project_Transmitter/blob/feature/mod_integration/vhdl/modulation/symbol_timing.vhd)
-- Revisions:
--  V1.0: Created 29/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--  Testbench MUST be run for at least
--  1) Synchronous Reset Test
--  2) Enable and Mute Gating Test
---------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity symbol_tb is
end entity symbol_tb;

architecture testbench of symbol_tb is

  constant G_CLKS_PER_SYMBOL : integer := 100;

  signal clk           : std_logic := '0';
  signal reset         : std_logic := '0';
  signal enable        : std_logic := '0';
  signal mute          : std_logic := '0';
  signal symbol_en     : std_logic;
  signal half_symbol_en : std_logic;

begin   -- <<< THIS is critical

  clk <= not clk after 1 ns;  -- Clock generator

  dut: entity work.symbol_timer(rtl)
    generic map (
      G_CLKS_PER_SYMBOL => G_CLKS_PER_SYMBOL
    )
    port map (
      clk           => clk,
      reset         => reset,
      enable        => enable,
      symbol_en     => symbol_en,
      half_symbol_en=> half_symbol_en,
      mute          => mute
    );
    
    stimulus:
    process
      begin 
        enable <= '0';
        mute <= '0';
          
        -- Test 1: Synchronous Reset Test
        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk); -- Add more if increased simulation clarity is required
        reset <= '0';
        wait until rising_edge(clk);
        assert (symbol_en = '0') report "TEST 1 FAILED: Reset does not set symbol strobe to 0" severity failure;
        assert (half_symbol_en = '0') report "TEST 1 FAILED: Reset does not set half-symbol strobe to 0" severity failure;
        report "TEST 1 PASSED: Synchronous reset performs as expected" severity note;
    
        -- Test 2: Enable and Mute Gating Test
        enable <= '0';
        mute   <= '0';
        for k in 1 to (G_CLKS_PER_SYMBOL+2) loop
          wait until rising_edge(clk);
          assert (symbol_en='0' and half_symbol_en='0')
            report "TEST 2 FAILED: strobe asserted while enable=0"
            severity error;
        end loop;
        enable <= '1';
        mute   <= '1';
        for k in 1 to (G_CLKS_PER_SYMBOL+2) loop
          wait until rising_edge(clk);
          assert (symbol_en='0' and half_symbol_en='0')
            report "TEST 2 FAILED: strobe asserted while mute=1"
            severity error;
        end loop;
        mute <= '0';
        wait until rising_edge(clk);
        report "TEST 2 PASSED: enable/mute gating works" severity note;
        report "ALL TESTS PASSED" severity note;
        wait;
      end process;
end architecture testbench;
