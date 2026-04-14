--16/03/2026

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmit_mux is
     port (
        path_sel_i : in std_logic_vector(1 downto 0);
        prbs_bit_i : in std_logic;
        tc_bit_i : in std_logic;
        tm_bit_i : in std_logic;
        tx_bit_o : out std_logic
     );
end transmit_mux;

architecture rtl of transmit_mux is
begin
    with path_sel_i select
        tx_bit_o <= prbs_bit_i when "00",
                    tc_bit_i when "01",
                    tm_bit_i when "10",
                    prbs_bit_i when others;
end rtl;
