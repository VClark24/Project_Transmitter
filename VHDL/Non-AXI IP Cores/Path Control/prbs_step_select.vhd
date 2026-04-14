library ieee;
use ieee.std_logic_1164.all; -- Provides std_logic and std_logic_vector
use ieee.numeric_std.all;    -- Provides unsigned and vector arithmetic

entity prbs_step_select is
    port (
        waveform_sel : in std_logic_vector(1 downto 0); -- BPSK expcept for 11 (OQPSK)
        symbol_en : in std_logic;
        half_symbol_en : in std_logic;
        prbs_step_o : out std_logic
    );
 end entity;
 
 architecture rtl of prbs_step_select is
 begin
     process(waveform_sel, symbol_en, half_symbol_en)
        begin
            if waveform_sel = "11" then
                prbs_step_o <= symbol_en or half_symbol_en;
            else
                prbs_step_o <= symbol_en;
            end if;
     end process;
 end architecture;
