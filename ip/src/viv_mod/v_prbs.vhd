-- #########################################################################
-- PRBS Generator (PRBS7 / PRBS15 / PRBS23 / PRBS31)
--  * Active-low reset
--  * Correct LFSR length per polynomial
--  * Left-shift, MSB output
--  * Zero-seed protection
-- #########################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prbs_gen is
    generic(
        -- 1 = PRBS7  (x^7  + x^6  + 1)
        -- 2 = PRBS15 (x^15 + x^14 + 1)
        -- 3 = PRBS23 (x^23 + x^18 + 1)
        -- 4 = PRBS31 (x^31 + x^28 + 1)
        G_POLY_SEL : integer := 1;

        -- 32-bit seed (truncated to actual LFSR length)
        G_SEED     : std_logic_vector(31 downto 0) := x"00000001"
    );
    port(
        clk      : in  std_logic;
        rst_n    : in  std_logic;    -- ACTIVE-LOW RESET
        enable   : in  std_logic := '1';
        prbs_out : out std_logic
    );
end entity;

architecture rtl of prbs_gen is

    -------------------------------------------------------------------------
    -- Helper: LFSR length from polynomial select
    -------------------------------------------------------------------------
    function poly_length(sel : integer) return integer is
    begin
        case sel is
            when 1 => return 7;
            when 2 => return 15;
            when 3 => return 23;
            when 4 => return 31;
            when others => return 7;
        end case;
    end function;

    constant LFSR_LEN : integer := poly_length(G_POLY_SEL);

    -------------------------------------------------------------------------
    -- Helper: all-zero vector of given length
    -------------------------------------------------------------------------
    function zero_vec(n : integer) return std_logic_vector is
        variable tmp : std_logic_vector(n-1 downto 0);
    begin
        tmp := (others => '0');
        return tmp;
    end function;

    -------------------------------------------------------------------------
    -- Helper: minimal non-zero seed (000...001)
    -------------------------------------------------------------------------
    function min_seed(n : integer) return std_logic_vector is
        variable tmp : std_logic_vector(n-1 downto 0);
    begin
        tmp := (others => '0');
        tmp(0) := '1';
        return tmp;
    end function;

    -------------------------------------------------------------------------
    -- LFSR state (dynamic width)
    -------------------------------------------------------------------------
    signal lfsr : std_logic_vector(LFSR_LEN-1 downto 0);

    -------------------------------------------------------------------------
    -- Feedback bit
    -------------------------------------------------------------------------
    signal feedback : std_logic;

begin

    -------------------------------------------------------------------------
    -- Polynomial taps (Fibonacci LFSR, MSB = lfsr(LFSR_LEN-1))
    -------------------------------------------------------------------------
    with G_POLY_SEL select feedback <=
        lfsr(6)  xor lfsr(5)   when 1,  -- PRBS7
        lfsr(14) xor lfsr(13)  when 2,  -- PRBS15
        lfsr(22) xor lfsr(17)  when 3,  -- PRBS23
        lfsr(30) xor lfsr(27)  when 4,  -- PRBS31
        lfsr(6)  xor lfsr(5)   when others;

    -------------------------------------------------------------------------
    -- LFSR update: left-shift, feedback into LSB, output = MSB
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then

            if rst_n = '0' then
                -- Truncate seed to active width, protect against all-zero
                if G_SEED(LFSR_LEN-1 downto 0) = zero_vec(LFSR_LEN) then
                    lfsr <= min_seed(LFSR_LEN);             -- 000...001
                else
                    lfsr <= G_SEED(LFSR_LEN-1 downto 0);
                end if;

            elsif enable = '1' then
                -- Shift left: MSB shifts out, feedback enters at bit 0
                lfsr <= lfsr(LFSR_LEN-2 downto 0) & feedback;
            end if;

        end if;
    end process;

    -------------------------------------------------------------------------
    -- Output PRBS bit (MSB)
    -------------------------------------------------------------------------
    prbs_out <= lfsr(LFSR_LEN-1);

end architecture;
