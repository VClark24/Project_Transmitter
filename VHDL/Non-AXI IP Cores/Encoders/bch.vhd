-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: BCH (Telecommand) Encoding
-- Revisions:
--  V1.0: Created 19/02/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
--  V1.1 : 30/03/2026 adds filler bit and complement bit
--  V1.2 : 09/04/2026 add input_ready port
-- Comments:
--   Compatible with CCSDS 231.0-B-4: TC Synchronisation and Channel Coding
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bch_encoder is
    generic(
        G_K_INFO_BITS   : natural := 56;
        G_R_PARITY_BITS : natural := 7
    );
    port(
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        enable        : in  std_logic;
        data_in       : in  std_logic;
        data_valid    : in  std_logic;
        input_ready   : out std_logic; 
        coded_bit_out : out std_logic;
        code_valid    : out std_logic;
        busy          : out std_logic
    );
end entity bch_encoder;

architecture rtl of bch_encoder is
    type state_bch is (S_IDLE, S_INFO, S_PARITY, S_FILLER);
    signal state       : state_bch := S_IDLE;
    signal state_n     : state_bch := S_IDLE;

    signal info_count   : unsigned(5 downto 0) := (others => '0');
    signal info_count_n : unsigned(5 downto 0) := (others => '0');
    signal info_done    : std_logic;

    signal parity_count   : unsigned(2 downto 0) := (others => '0');
    signal parity_count_n : unsigned(2 downto 0) := (others => '0');
    signal parity_done    : std_logic;

    signal parity_reg   : std_logic_vector(6 downto 0) := (others => '0');
    signal parity_reg_n : std_logic_vector(6 downto 0) := (others => '0');

    signal code_bit_out_r : std_logic := '0';
    signal code_bit_out_n : std_logic := '0';
    signal code_valid_r   : std_logic := '0';
    signal code_valid_n   : std_logic := '0';
    signal busy_r         : std_logic := '0';
    signal busy_n         : std_logic := '0';
begin
    info_done   <= '1' when info_count   = to_unsigned(G_K_INFO_BITS   - 1, info_count'length)   else '0';
    parity_done <= '1' when parity_count = to_unsigned(G_R_PARITY_BITS - 1, parity_count'length) else '0';

    input_ready   <= '1' when (state = S_IDLE or state = S_INFO) else '0';
    coded_bit_out <= code_bit_out_r;
    code_valid    <= code_valid_r;
    busy          <= busy_r;

    p_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state          <= S_IDLE;
                info_count     <= (others => '0');
                parity_count   <= (others => '0');
                parity_reg     <= (others => '0');
                code_bit_out_r <= '0';
                code_valid_r   <= '0';
                busy_r         <= '0';
            else
                state          <= state_n;
                info_count     <= info_count_n;
                parity_count   <= parity_count_n;
                parity_reg     <= parity_reg_n;
                code_bit_out_r <= code_bit_out_n;
                code_valid_r   <= code_valid_n;
                busy_r         <= busy_n;
            end if;
        end if;
    end process;

    p_comb : process(
        state, enable, data_valid, data_in,
        info_count, parity_count, parity_reg,
        code_bit_out_r, busy_r
    )
        variable feedback : std_logic;
    begin
        state_n        <= state;
        info_count_n   <= info_count;
        parity_count_n <= parity_count;
        parity_reg_n   <= parity_reg;
        code_bit_out_n <= code_bit_out_r;
        code_valid_n   <= '0';
        busy_n         <= busy_r;

        case state is
            when S_IDLE =>
                busy_n <= '0';

                if enable = '1' and data_valid = '1' then
                    busy_n         <= '1';
                    code_valid_n   <= '1';
                    code_bit_out_n <= data_in;  -- systematic output: first information bit
                    info_count_n   <= to_unsigned(1, info_count_n'length);
                    parity_count_n <= (others => '0');

                    feedback := data_in xor parity_reg(6);
                    parity_reg_n(6) <= parity_reg(5) xor feedback;
                    parity_reg_n(5) <= parity_reg(4);
                    parity_reg_n(4) <= parity_reg(3);
                    parity_reg_n(3) <= parity_reg(2);
                    parity_reg_n(2) <= parity_reg(1) xor feedback;
                    parity_reg_n(1) <= parity_reg(0);
                    parity_reg_n(0) <= feedback;

                    state_n <= S_INFO;
                end if;

            when S_INFO =>
                busy_n <= '1';

                if data_valid = '1' then
                    code_valid_n   <= '1';
                    code_bit_out_n <= data_in;  -- pass information bits directly

                    feedback := data_in xor parity_reg(6);
                    parity_reg_n(6) <= parity_reg(5) xor feedback;
                    parity_reg_n(5) <= parity_reg(4);
                    parity_reg_n(4) <= parity_reg(3);
                    parity_reg_n(3) <= parity_reg(2);
                    parity_reg_n(2) <= parity_reg(1) xor feedback;
                    parity_reg_n(1) <= parity_reg(0);
                    parity_reg_n(0) <= feedback;

                    info_count_n <= info_count + 1;

                    if info_done = '1' then
                        state_n        <= S_PARITY;
                        parity_count_n <= (others => '0');
                    end if;
                end if;

            when S_PARITY =>
                busy_n         <= '1';
                code_valid_n   <= '1';
                code_bit_out_n <= not parity_reg(6);  -- CCSDS complemented parity bit
                parity_reg_n   <= parity_reg(5 downto 0) & '0';
                parity_count_n <= parity_count + 1;

                if parity_done = '1' then
                    state_n        <= S_FILLER;
                    parity_count_n <= (others => '0');
                end if;

            when S_FILLER =>
                busy_n         <= '1';
                code_valid_n   <= '1';
                code_bit_out_n <= '0';  -- CCSDS filler bit

                state_n        <= S_IDLE;
                info_count_n   <= (others => '0');
                parity_count_n <= (others => '0');
                parity_reg_n   <= (others => '0');

            when others =>
                state_n        <= S_IDLE;
                info_count_n   <= (others => '0');
                parity_count_n <= (others => '0');
                parity_reg_n   <= (others => '0');
                code_bit_out_n <= '0';
                code_valid_n   <= '0';
                busy_n         <= '0';
        end case;
    end process;
end architecture rtl;
