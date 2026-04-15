-----------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Transmit Multiplexer
-- Revisions:
--  V1.0: Created 16/03/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--  Essentially rejoins the three paths (telecommand, telemetry and bypassing framing + encoding
--  If telecommand is selected, the output of the BCH encoder is fed into the mapper
--  If telemetry is selected, the output of the convolutional encoder is fed into the mapper
--  If beacon or FHSS is selected, the output of the PRBS23 block is fed straight into the mapper
--  Takes the path_sel signal (0 for bypass, 1 for telecommand, 2 for telemetry) from the path selecter
---------------------------------------------------------------------------------------------------------
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
