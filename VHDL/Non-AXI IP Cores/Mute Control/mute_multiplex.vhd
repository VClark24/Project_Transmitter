-- 16/03/2026

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_multiplex is
   port ( 
    clk : in std_logic;
    rst_n : in std_logic;
    
    mute_sw : in std_logic;  -- Mute from SW
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
