-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Convolutional (Telemetry) Encoding
-- Revisions:
--  V1.0: Created 22/02/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--   Compatible with CCSDS 131.0-B-5: TM Synchronization and Channel Coding
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_encoder is
  port (
    clk : in std_logic;
    rst_n : in std_logic;
    enable : in std_logic;

    in_bit : in std_logic;
    in_valid : in std_logic;
    in_ready : out std_logic;

    out_bit : out std_logic;
    out_valid : out std_logic;

    busy : out std_logic
    );
end entity conv_encoder;

architecture rtl of conv_encoder is
  type tmconv is (S_IDLE, S_OUT_C2);
  signal state : tmconv := S_IDLE;

  signal shift_reg : std_logic_vector(5 downto 0) := (others => '0');
  signal c2_store : std_logic := '0';

begin
  process(clk)
  variable c1 : std_logic;
  variable c2: std_logic;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state      <= S_IDLE;
        shift_reg  <= (others => '0');
        c2_store <= '0';
        out_bit    <= '0';
        out_valid  <= '0';
      else
        out_valid <= '0';
        case state is
            when S_IDLE =>
              if enable = '1' and in_valid = '1' then
                c1 := in_bit xor shift_reg(5) xor shift_reg(4) xor shift_reg(3) xor shift_reg(0);
                c2 := in_bit xor shift_reg(4) xor shift_reg(3) xor shift_reg(1) xor shift_reg(0);
                c2_store <= not c2;
                out_bit <= c1;
                out_valid <= '1';
                shift_reg <= in_bit & shift_reg(5 downto 1);
                state <= S_OUT_C2;
              end if;
            when S_OUT_C2 =>
              out_bit <= c2_store;
              out_valid <= '1';
              state <= S_IDLE;
         end case;
       end if;
      end if;
  end process;
  in_ready <= '1' when (state = S_IDLE) else '0';
  busy <= '1' when (state = S_OUT_C2) else '0';
end architecture rtl;
