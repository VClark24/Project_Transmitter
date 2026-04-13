-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Symbol Timing Block
-- Revisions:
--  V1.0: Created 26/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
--  V1.1: 13/03/2026 sample flow control added
--  V1.2: 20/03/2026 changes to target 25 Msamples/second sample rate (seperate symbol and sample rate counters)
-- Comments:
--   Number of clocks per sample must be even
--   Provides strobes for mapper.vhd
--   symbol_en will release the I sample and half_symbol_en the Q sample
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity symbol_timer is
  generic(
    G_CLKS_PER_SAMPLE : integer := 4;
    G_SAMPLES_PER_SYMBOL : integer := 4 -- MUST be even
    );
  port(
    clk : in std_logic;
    reset : in std_logic;
    enable : in std_logic;
    symbol_en : out std_logic := '0';
    half_symbol_en : out std_logic := '0';
    sample_en : out std_logic := '0'
    );
end entity symbol_timer;

architecture rtl of symbol_timer is
  signal clk_count : integer range 0 to G_CLKS_PER_SAMPLE -1 := 0;
  signal sample_count : integer range 0 to G_SAMPLES_PER_SYMBOL - 1 := 0;
  
begin

  process(clk) 
  begin
    if rising_edge(clk) then
      if reset = '1' then
        clk_count <= 0;
        sample_count <= 0;
        sample_en <= '0';
        symbol_en <= '0';
        half_symbol_en <= '0';

      elsif enable = '1' then
        
        sample_en <= '0';
        symbol_en <= '0';
        half_symbol_en <= '0';
        
        if clk_count = G_CLKS_PER_SAMPLE - 1 then
          clk_count <= 0;
          sample_en <= '1';
        
          if sample_count = G_SAMPLES_PER_SYMBOL - 1 then
            sample_count <= 0;
            symbol_en <= '1';
        
          elsif sample_count = (G_SAMPLES_PER_SYMBOL / 2) - 1 then
            sample_count <= sample_count + 1;
            half_symbol_en <= '1';
        
          else
            sample_count <= sample_count + 1;
          end if;
        
        else
          clk_count <= clk_count + 1;
        end if;
               
      else
        -- block disabled
        clk_count <= 0;
        sample_count <= 0;
        sample_en <= '0';
        symbol_en <= '0';
        half_symbol_en <= '0';
      end if;
    end if;
  end process;

end architecture rtl; 
