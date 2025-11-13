---------------------------------------------------------------------------
-- v_map: BPSK / QPSK Modulation Mapper (symmetric full-scale)
--
--   mod_sel = '0' → BPSK
--       bit_in : single bit
--       I = ±AMP_POS / AMP_NEG, Q = 0
--
--   mod_sel = '1' → QPSK (Gray-coded)
--       bits_in :
--         00 →  I=+1, Q=+1
--         01 →  I=-1, Q=+1
--         11 →  I=-1, Q=-1
--         10 →  I=+1, Q=-1
--
-- Amplitudes (for G_WIDTH=16):
--   AMP_POS =  32767  (0x7FFF)
--   AMP_NEG = -32768  (0x8000)
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity v_map is
    generic(
        G_WIDTH : integer := 16
    );
    port(
        clk     : in  std_logic;
        rst_n   : in  std_logic;

        -- Inputs
        bit_in   : in  std_logic;                       -- BPSK data bit
        bits_in  : in  std_logic_vector(1 downto 0);    -- QPSK symbol bits
        mod_sel  : in  std_logic;                       -- 0=BPSK, 1=QPSK

        -- Outputs
        i_out    : out signed(G_WIDTH-1 downto 0);
        q_out    : out signed(G_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of v_map is

    -- Positive and negative full-scale values
    constant AMP_POS : integer := (2**(G_WIDTH-1)) - 1;  -- +32767 for 16 bits
    constant AMP_NEG : integer := -(2**(G_WIDTH-1));     -- -32768 for 16 bits

    signal i_sig, q_sig : signed(G_WIDTH-1 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if rst_n = '0' then
                i_sig <= (others => '0');
                q_sig <= (others => '0');

            else
                -----------------------------------------------------------
                -- BPSK MODE
                -----------------------------------------------------------
                if mod_sel = '0' then

                    if bit_in = '0' then
                        i_sig <= to_signed(AMP_POS, G_WIDTH);  -- +1
                    else
                        i_sig <= to_signed(AMP_NEG, G_WIDTH);  -- -1
                    end if;

                    q_sig <= (others => '0');                  -- no Q

                -----------------------------------------------------------
                -- QPSK MODE (Gray-coded)
                -----------------------------------------------------------
                else
                    case bits_in is

                        -- 00 → +I, +Q
                        when "00" =>
                            i_sig <= to_signed(AMP_POS, G_WIDTH);
                            q_sig <= to_signed(AMP_POS, G_WIDTH);

                        -- 01 → -I, +Q
                        when "01" =>
                            i_sig <= to_signed(AMP_NEG, G_WIDTH);
                            q_sig <= to_signed(AMP_POS, G_WIDTH);

                        -- 11 → -I, -Q
                        when "11" =>
                            i_sig <= to_signed(AMP_NEG, G_WIDTH);
                            q_sig <= to_signed(AMP_NEG, G_WIDTH);

                        -- 10 → +I, -Q
                        when "10" =>
                            i_sig <= to_signed(AMP_POS, G_WIDTH);
                            q_sig <= to_signed(AMP_NEG, G_WIDTH);

                        when others =>
                            i_sig <= (others => '0');
                            q_sig <= (others => '0');
                    end case;
                end if;

            end if;
        end if;
    end process;

    i_out <= i_sig;
    q_out <= q_sig;

end architecture;