-- 16/03/2026

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity path_enable_decoder is
     port (
        path_select_i : in std_logic_vector(1 downto 0);
        
        tc_enable_o : out std_logic;
        tm_enable_o : out std_logic
      );
end path_enable_decoder;

architecture rtl of path_enable_decoder is
begin
    process(path_select_i)
    begin
        tc_enable_o <= '0';
        tm_enable_o <= '0';

        case path_select_i is 
            when "01" =>
                tc_enable_o <= '1';
            when "10" =>
                tm_enable_o <= '1';
            when others =>
                null;
        end case; 
    end process;  
end rtl;
