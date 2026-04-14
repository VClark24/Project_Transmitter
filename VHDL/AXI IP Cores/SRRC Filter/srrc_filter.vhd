----------------------------------------------------------------------------------
-- Company: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: SRRC Filter
-- Comments:
--   Previous versions were very simplistic and did not meet timing constraints.
--   V1.4: Deeper timing-oriented rewrite
--   - Stage 1: shift register update + symmetric sample pairing
--   - Stage 2: multiply by SRRC coefficients
--   - Stage 3: 21 -> 11 adder reduction
--   - Stage 4: 11 -> 6 adder reduction
--   - Stage 5: 6 -> 3 adder reduction
--   - Stage 6: 3 -> 1 final sum
--   - Stage 7: scale + saturate to 16-bit output
-- Notes:
--   - This is a pipelined FIR, so output latency is several sample_en_i pulses.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity srrc_filter is
    port (
        clk : in std_logic;
        rst : in std_logic;
        sample_en_i      : in std_logic;
        symbol_en_i      : in std_logic;
        half_symbol_en_i : in std_logic;
        i_symbol_i : in signed(15 downto 0);
        q_symbol_i : in signed(15 downto 0);
        i_out_o : out signed(15 downto 0);
        q_out_o : out signed(15 downto 0)
    );
end srrc_filter;

architecture rtl of srrc_filter is

    constant NTAPS      : integer := 41;
    constant HALF_TAPS  : integer := 20;
    constant TAP_BITS   : integer := 16;
    constant DATA_BITS  : integer := 16;
    constant PAIR_BITS  : integer := DATA_BITS + 1;        -- 17
    constant PROD_BITS  : integer := PAIR_BITS + TAP_BITS; -- 33
    constant ACC_BITS   : integer := 40;

    type tap_array_t    is array (0 to NTAPS - 1) of signed(TAP_BITS - 1 downto 0);
    type sample_array_t is array (0 to NTAPS - 1) of signed(DATA_BITS - 1 downto 0);

    type pair_array_t   is array (0 to HALF_TAPS - 1) of signed(PAIR_BITS - 1 downto 0);
    type prod_array_t   is array (0 to HALF_TAPS) of signed(PROD_BITS - 1 downto 0);

    type sum21_array_t  is array (0 to 10) of signed(ACC_BITS - 1 downto 0);
    type sum11_array_t  is array (0 to 5)  of signed(ACC_BITS - 1 downto 0);
    type sum6_array_t   is array (0 to 2)  of signed(ACC_BITS - 1 downto 0);

    signal i_shift : sample_array_t := (others => (others => '0'));
    signal q_shift : sample_array_t := (others => (others => '0'));

    constant COEFFS : tap_array_t := (
          to_signed(   123, TAP_BITS),
          to_signed(   -39, TAP_BITS),
          to_signed(  -190, TAP_BITS),
          to_signed(  -168, TAP_BITS),
          to_signed(    33, TAP_BITS),
          to_signed(   218, TAP_BITS),
          to_signed(   157, TAP_BITS),
          to_signed(  -156, TAP_BITS),
          to_signed(  -417, TAP_BITS),
          to_signed(  -242, TAP_BITS),
          to_signed(   420, TAP_BITS),
          to_signed(  1071, TAP_BITS),
          to_signed(   936, TAP_BITS),
          to_signed(  -362, TAP_BITS),
          to_signed( -2215, TAP_BITS),
          to_signed( -3091, TAP_BITS),
          to_signed( -1388, TAP_BITS),
          to_signed(  3390, TAP_BITS),
          to_signed(  9958, TAP_BITS),
          to_signed( 15682, TAP_BITS),
          to_signed( 17952, TAP_BITS),
          to_signed( 15682, TAP_BITS),
          to_signed(  9958, TAP_BITS),
          to_signed(  3390, TAP_BITS),
          to_signed( -1388, TAP_BITS),
          to_signed( -3091, TAP_BITS),
          to_signed( -2215, TAP_BITS),
          to_signed(  -362, TAP_BITS),
          to_signed(   936, TAP_BITS),
          to_signed(  1071, TAP_BITS),
          to_signed(   420, TAP_BITS),
          to_signed(  -242, TAP_BITS),
          to_signed(  -417, TAP_BITS),
          to_signed(  -156, TAP_BITS),
          to_signed(   157, TAP_BITS),
          to_signed(   218, TAP_BITS),
          to_signed(    33, TAP_BITS),
          to_signed(  -168, TAP_BITS),
          to_signed(  -190, TAP_BITS),
          to_signed(   -39, TAP_BITS),
          to_signed(   123, TAP_BITS)
    );

    -- Stage 1
    signal s1_valid    : std_logic := '0';
    signal i_pair_s1   : pair_array_t := (others => (others => '0'));
    signal q_pair_s1   : pair_array_t := (others => (others => '0'));
    signal i_centre_s1 : signed(PAIR_BITS - 1 downto 0) := (others => '0');
    signal q_centre_s1 : signed(PAIR_BITS - 1 downto 0) := (others => '0');

    -- Stage 2
    signal s2_valid    : std_logic := '0';
    signal i_prod_s2   : prod_array_t := (others => (others => '0'));
    signal q_prod_s2   : prod_array_t := (others => (others => '0'));

    -- Stage 3 : 21 -> 11
    signal s3_valid    : std_logic := '0';
    signal i_l1_s3     : sum21_array_t := (others => (others => '0'));
    signal q_l1_s3     : sum21_array_t := (others => (others => '0'));

    -- Stage 4 : 11 -> 6
    signal s4_valid    : std_logic := '0';
    signal i_l2_s4     : sum11_array_t := (others => (others => '0'));
    signal q_l2_s4     : sum11_array_t := (others => (others => '0'));

    -- Stage 5 : 6 -> 3
    signal s5_valid    : std_logic := '0';
    signal i_l3_s5     : sum6_array_t := (others => (others => '0'));
    signal q_l3_s5     : sum6_array_t := (others => (others => '0'));

    -- Stage 6 : 3 -> 1
    signal s6_valid    : std_logic := '0';
    signal i_sum_s6    : signed(ACC_BITS - 1 downto 0) := (others => '0');
    signal q_sum_s6    : signed(ACC_BITS - 1 downto 0) := (others => '0');

    -- Output stage
    signal i_out_r     : signed(15 downto 0) := (others => '0');
    signal q_out_r     : signed(15 downto 0) := (others => '0');

    function sat16(x : signed(ACC_BITS - 1 downto 0)) return signed is
        variable y : signed(15 downto 0);
        constant MAX16 : signed(ACC_BITS - 1 downto 0) := to_signed(32767, ACC_BITS);
        constant MIN16 : signed(ACC_BITS - 1 downto 0) := to_signed(-32768, ACC_BITS);
    begin
        if x > MAX16 then
            y := to_signed(32767, 16);
        elsif x < MIN16 then
            y := to_signed(-32768, 16);
        else
            y := resize(x, 16);
        end if;
        return y;
    end function;

begin

    i_out_o <= i_out_r;
    q_out_o <= q_out_r;

    process(clk)
        variable i_sample_v : signed(DATA_BITS - 1 downto 0);
        variable q_sample_v : signed(DATA_BITS - 1 downto 0);

        variable i_shift_v  : sample_array_t;
        variable q_shift_v  : sample_array_t;

        variable i_pair_v   : pair_array_t;
        variable q_pair_v   : pair_array_t;
        variable i_centre_v : signed(PAIR_BITS - 1 downto 0);
        variable q_centre_v : signed(PAIR_BITS - 1 downto 0);

        variable i_prod_v   : prod_array_t;
        variable q_prod_v   : prod_array_t;

        variable i_l1_v     : sum21_array_t;
        variable q_l1_v     : sum21_array_t;

        variable i_l2_v     : sum11_array_t;
        variable q_l2_v     : sum11_array_t;

        variable i_l3_v     : sum6_array_t;
        variable q_l3_v     : sum6_array_t;

        variable i_sum_v    : signed(ACC_BITS - 1 downto 0);
        variable q_sum_v    : signed(ACC_BITS - 1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i_shift      <= (others => (others => '0'));
                q_shift      <= (others => (others => '0'));

                s1_valid     <= '0';
                i_pair_s1    <= (others => (others => '0'));
                q_pair_s1    <= (others => (others => '0'));
                i_centre_s1  <= (others => '0');
                q_centre_s1  <= (others => '0');

                s2_valid     <= '0';
                i_prod_s2    <= (others => (others => '0'));
                q_prod_s2    <= (others => (others => '0'));

                s3_valid     <= '0';
                i_l1_s3      <= (others => (others => '0'));
                q_l1_s3      <= (others => (others => '0'));

                s4_valid     <= '0';
                i_l2_s4      <= (others => (others => '0'));
                q_l2_s4      <= (others => (others => '0'));

                s5_valid     <= '0';
                i_l3_s5      <= (others => (others => '0'));
                q_l3_s5      <= (others => (others => '0'));

                s6_valid     <= '0';
                i_sum_s6     <= (others => '0');
                q_sum_s6     <= (others => '0');

                i_out_r      <= (others => '0');
                q_out_r      <= (others => '0');

            else
              
                -- Stage 7: scale + saturate
                if s6_valid = '1' then
                    i_out_r <= sat16(shift_right(i_sum_s6, 15));
                    q_out_r <= sat16(shift_right(q_sum_s6, 15));
                end if;


                -- Stage 6: 3 -> 1
                s6_valid <= s5_valid;

                if s5_valid = '1' then
                    i_sum_v := (i_l3_s5(0) + i_l3_s5(1)) + i_l3_s5(2);
                    q_sum_v := (q_l3_s5(0) + q_l3_s5(1)) + q_l3_s5(2);

                    i_sum_s6 <= i_sum_v;
                    q_sum_s6 <= q_sum_v;
                end if;

                -- Stage 5: 6 -> 3
                s5_valid <= s4_valid;

                if s4_valid = '1' then
                    for k in 0 to 2 loop
                        i_l3_v(k) := i_l2_s4(2*k) + i_l2_s4(2*k + 1);
                        q_l3_v(k) := q_l2_s4(2*k) + q_l2_s4(2*k + 1);
                    end loop;

                    i_l3_s5 <= i_l3_v;
                    q_l3_s5 <= q_l3_v;
                end if;

                -- Stage 4: 11 -> 6
                s4_valid <= s3_valid;

                if s3_valid = '1' then
                    for k in 0 to 4 loop
                        i_l2_v(k) := i_l1_s3(2*k) + i_l1_s3(2*k + 1);
                        q_l2_v(k) := q_l1_s3(2*k) + q_l1_s3(2*k + 1);
                    end loop;

                    i_l2_v(5) := i_l1_s3(10);
                    q_l2_v(5) := q_l1_s3(10);

                    i_l2_s4 <= i_l2_v;
                    q_l2_s4 <= q_l2_v;
                end if;

                -- Stage 3: 21 -> 11
                s3_valid <= s2_valid;

                if s2_valid = '1' then
                    for k in 0 to 9 loop
                        i_l1_v(k) := resize(i_prod_s2(2*k), ACC_BITS) + resize(i_prod_s2(2*k + 1), ACC_BITS);
                        q_l1_v(k) := resize(q_prod_s2(2*k), ACC_BITS) + resize(q_prod_s2(2*k + 1), ACC_BITS);
                    end loop;

                    i_l1_v(10) := resize(i_prod_s2(20), ACC_BITS);
                    q_l1_v(10) := resize(q_prod_s2(20), ACC_BITS);

                    i_l1_s3 <= i_l1_v;
                    q_l1_s3 <= q_l1_v;
                end if;

                -- Stage 2: products
                s2_valid <= s1_valid;

                if s1_valid = '1' then
                    for k in 0 to HALF_TAPS - 1 loop
                        i_prod_v(k) := i_pair_s1(k) * COEFFS(k);
                        q_prod_v(k) := q_pair_s1(k) * COEFFS(k);
                    end loop;

                    i_prod_v(HALF_TAPS) := i_centre_s1 * COEFFS(HALF_TAPS);
                    q_prod_v(HALF_TAPS) := q_centre_s1 * COEFFS(HALF_TAPS);

                    i_prod_s2 <= i_prod_v;
                    q_prod_s2 <= q_prod_v;
                end if;

                -- Stage 1: shift register update + symmetric pair sums
                s1_valid <= sample_en_i;

                if sample_en_i = '1' then
                    if symbol_en_i = '1' then
                        i_sample_v := i_symbol_i;
                    else
                        i_sample_v := (others => '0');
                    end if;

                    if half_symbol_en_i = '1' then
                        q_sample_v := q_symbol_i;
                    else
                        q_sample_v := (others => '0');
                    end if;

                    i_shift_v := i_shift;
                    q_shift_v := q_shift;

                    for k in NTAPS - 1 downto 1 loop
                        i_shift_v(k) := i_shift_v(k - 1);
                        q_shift_v(k) := q_shift_v(k - 1);
                    end loop;

                    i_shift_v(0) := i_sample_v;
                    q_shift_v(0) := q_sample_v;

                    i_shift <= i_shift_v;
                    q_shift <= q_shift_v;

                    for k in 0 to HALF_TAPS - 1 loop
                        i_pair_v(k) := resize(i_shift_v(k), PAIR_BITS) + resize(i_shift_v(NTAPS - 1 - k), PAIR_BITS);
                        q_pair_v(k) := resize(q_shift_v(k), PAIR_BITS) + resize(q_shift_v(NTAPS - 1 - k), PAIR_BITS);
                    end loop;

                    i_centre_v := resize(i_shift_v(HALF_TAPS), PAIR_BITS);
                    q_centre_v := resize(q_shift_v(HALF_TAPS), PAIR_BITS);

                    i_pair_s1   <= i_pair_v;
                    q_pair_s1   <= q_pair_v;
                    i_centre_s1 <= i_centre_v;
                    q_centre_s1 <= q_centre_v;
                end if;
            end if;
        end if;
    end process;

end rtl;
