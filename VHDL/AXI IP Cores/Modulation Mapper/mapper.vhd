-------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Modulation Mapper
-- Revisions:
--  V1.0: Created 25/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter/new/feature/mod_integration)
--  V1.1: 16/02/2026 change mapping and remove Telemetry Category B
--  V1.2: 05/03/2026 change mapping (00, 01 and 10 for BPSK, 11 for OQPSK)
--  V1.3: 13/03/2026 change G_WIDTH from 16 to 12 to prevent clipping in SRRC
--  V1.4: 18/03/2026 add bit_advance_o so source only advances after modulation
--  V1.5: 20/03/2026 to remove bit_advance_o
-- Comments:
--  BPSK mapping (0 -> -1, 1 -> +1)
--  OQPSK mapping (00 -> I = +1 and Q = +1, 01 -> I = +1 and Q = -1,
--                 10 -> I = -1 and Q = +1, 11 -> I = -1 and Q = -1)
--  BPSK for Waveform 0 (Telecommand), 1 (Telemetry), 2 (Beacon)
--  OQPSK for 3 (FHSS)
--  Q bitstream delayed by half a symbol period (T/2) relative to I
-------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mapper is
  generic(
    G_WIDTH : integer := 16;
    G_AMP   : integer := 2048  -- 2^12
  );
  port(
    clk            : in std_logic;
    reset          : in std_logic;
    enable         : in std_logic;
    symbol_en      : in std_logic;
    half_symbol_en : in std_logic;
    prbs_in        : in std_logic;
    i_out          : out signed(G_WIDTH-1 downto 0) := (others => '0');
    q_out          : out signed(G_WIDTH-1 downto 0) := (others => '0');
    waveform_sel   : in unsigned(1 downto 0)
  );
end entity mapper;

architecture rtl of mapper is

  constant AMP_POS : integer := G_AMP;
  constant AMP_NEG : integer := -G_AMP;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        i_out <= (others => '0');
        q_out <= (others => '0');
      
      elsif enable = '1' then
        -- BPSK: TC, TM, Beacon
        if waveform_sel = "00" or waveform_sel = "01" or waveform_sel = "10" then
          if symbol_en = '1' then
            if prbs_in = '0' then
              i_out <= to_signed(AMP_NEG, G_WIDTH);        -- 0 mapped to a negative amplitude
            else
              i_out <= to_signed(AMP_POS, G_WIDTH);        -- 1 mapped to a positive amplitude
            end if;
            q_out <= (others => '0');                      -- Q remains 0 in BPSK
          end if;

        -- OQPSK: FHSS
        elsif waveform_sel = "11" then
          if symbol_en = '1' then
            if prbs_in = '0' then
              i_out <= to_signed(AMP_NEG, G_WIDTH);     -- Same mapping
            else
              i_out <= to_signed(AMP_POS, G_WIDTH);     -- Same mapping
            end if;
          end if;

          if half_symbol_en = '1' then                 -- In OQPSK, Q is offset by half a symbol period relative to  I
            if prbs_in = '0' then
              q_out <= to_signed(AMP_NEG, G_WIDTH);   -- Same mapping
            else
              q_out <= to_signed(AMP_POS, G_WIDTH);   -- Same mapping
            end if;
          end if;
       -- Outputs tied low if mapper not in use
        else
          i_out <= (others => '0'); 
          q_out <= (others => '0');
        end if;

      else
        i_out <= (others => '0');
        q_out <= (others => '0');
      end if;
    end if;
  end process;

end architecture rtl;
