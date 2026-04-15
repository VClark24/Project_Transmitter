-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Mute Multiplexer
-- Revisions:
--  V1.0: Created 16/03/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--  This block will mute the output in these two following situations:
-- 
--  When the user wishes to mute, a register within the Transmit Controller block can be written
--  to. The mute_o signal is fed into this block. When high the outputs of the mapper are forced
--  low (0). These outputs are then fed into the SRRC filter
-- 
--  During waveform switching, a signal is sent from the Path Selector block to temporarily mute
--  the transmitter in order to prevent glitching. 
-----------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_multiplex is
   port ( 
    clk : in std_logic;
    rst_n : in std_logic;
    
    mute_sw : in std_logic;  -- Mute from SW (mute_o)
    mute_tmp : in std_logic;  -- Mute due to waveform switching
    
    inphase_i : in std_logic_vector(15 downto 0);
    quadrature_i : in std_logic_vector(15 downto 0);
    
    inphase_o : out std_logic_vector(15 downto 0);
    quadrature_o : out std_logic_vector(15 downto 0)
   );
end mute_multiplex;

architecture rtl of mute_multiplex is

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                inphase_o <= (others => '0');
                quadrature_o <= (others => '0');
            elsif mute_sw = '1' or mute_tmp = '1' then
                inphase_o <= (others => '0');
                quadrature_o <= (others => '0');
            else
                inphase_o <= inphase_i;
                quadrature_o <= quadrature_i;
            end if;
        end if;
    end process;      
end rtl;
