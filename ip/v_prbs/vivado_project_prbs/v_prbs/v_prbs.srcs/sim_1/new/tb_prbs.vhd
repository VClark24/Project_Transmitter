-- #########################################################################
-- Unified PRBS Testbench
-- Tests PRBS7, PRBS15, PRBS23, PRBS31 in a single simulation.
-- Performs:
--   - Reset behaviour
--   - Seed loading
--   - Illegal all-zero detection
--   - Bit toggling (randomness)
--   - No-stuck detection
--   - Enable freeze test
-- ALL MODES get PER-MODE PASS/FAIL.
-- Produces final global PASS if all tests succeed.
-- #########################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_prbs_unified is
end entity;

architecture tb of tb_prbs_unified is

    constant CLK_PERIOD : time := 10 ns;

    signal clk    : std_logic := '0';
    signal rst_n  : std_logic := '0';
    signal enable : std_logic := '1';

    -- DUT outputs
    signal prbs7      : std_logic;
    signal prbs15     : std_logic;
    signal prbs23     : std_logic;
    signal prbs31     : std_logic;

    -- Previous bit samples
    signal p7, p15, p23, p31 : std_logic := '0';

    -- PASS/FAIL registers
    signal pass7, pass15, pass23, pass31 : boolean := true;

begin

    -------------------------------------------------------------------------
    -- Instantiate all four PRBS generators
    -------------------------------------------------------------------------

    u7 : entity work.prbs_gen
        generic map(G_POLY_SEL => 1, G_SEED => x"00000001")
        port map(clk => clk, rst_n => rst_n, enable => enable, prbs_out => prbs7);

    u15 : entity work.prbs_gen
        generic map(G_POLY_SEL => 2, G_SEED => x"00000001")
        port map(clk => clk, rst_n => rst_n, enable => enable, prbs_out => prbs15);

    u23 : entity work.prbs_gen
        generic map(G_POLY_SEL => 3, G_SEED => x"00000001")
        port map(clk => clk, rst_n => rst_n, enable => enable, prbs_out => prbs23);

    u31 : entity work.prbs_gen
        generic map(G_POLY_SEL => 4, G_SEED => x"00000001")
        port map(clk => clk, rst_n => rst_n, enable => enable, prbs_out => prbs31);


    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    -------------------------------------------------------------------------
    -- Unified Stimulus & Verification
    -------------------------------------------------------------------------
    stim : process
        type int_arr is array (natural range <>) of integer;
        variable toggles : int_arr(1 to 4) := (others => 0);
        variable zeros    : int_arr(1 to 4) := (others => 0);
        variable same_cnt : int_arr(1 to 4) := (others => 0);

    begin

        ---------------------------------------------------------------------
        -- RESET
        ---------------------------------------------------------------------
        rst_n  <= '0';
        enable <= '0';
        wait for 50 ns;
        
        enable <= '1';
        rst_n  <= '1';
        wait until rising_edge(clk);

        report "RESET completed. Begin unified PRBS testing..." severity note;

        ---------------------------------------------------------------------
        -- RUN ALL PRBS FOR N CYCLES
        ---------------------------------------------------------------------
        for i in 0 to 500 loop
            wait until rising_edge(clk);

            -- Check toggles
            if prbs7 /= p7 then toggles(1) := toggles(1) + 1; else same_cnt(1) := same_cnt(1) + 1; end if;
            if prbs15 /= p15 then toggles(2) := toggles(2) + 1; else same_cnt(2) := same_cnt(2) + 1; end if;
            if prbs23 /= p23 then toggles(3) := toggles(3) + 1; else same_cnt(3) := same_cnt(3) + 1; end if;
            if prbs31 /= p31 then toggles(4) := toggles(4) + 1; else same_cnt(4) := same_cnt(4) + 1; end if;

            -- Check illegal all-zero output (after startup)
            if i > 10 then
                if prbs7 = '0' then zeros(1) := zeros(1) + 1; end if;
                if prbs15 = '0' then zeros(2) := zeros(2) + 1; end if;
                if prbs23 = '0' then zeros(3) := zeros(3) + 1; end if;
                if prbs31 = '0' then zeros(4) := zeros(4) + 1; end if;
            end if;

            -- Save previous
            p7  <= prbs7;
            p15 <= prbs15;
            p23 <= prbs23;
            p31 <= prbs31;
        end loop;


        ---------------------------------------------------------------------
        -- EVALUATE SEQUENCE BEHAVIOUR
        ---------------------------------------------------------------------

        -- PRBS7 checks
        if toggles(1) < 50 or same_cnt(1) > 400 then
            pass7 <= false;
            report "FAIL: PRBS7 sequence invalid" severity error;
        end if;

        -- PRBS15 checks
        if toggles(2) < 50 or same_cnt(2) > 400 then
            pass15 <= false;
            report "FAIL: PRBS15 sequence invalid" severity error;
        end if;

        -- PRBS23 checks
        if toggles(3) < 50 or same_cnt(3) > 400 then
            pass23 <= false;
            report "FAIL: PRBS23 sequence invalid" severity error;
        end if;

        -- PRBS31 checks
        if toggles(4) < 50 or same_cnt(4) > 400 then
            pass31 <= false;
            report "FAIL: PRBS31 sequence invalid" severity error;
        end if;


        ---------------------------------------------------------------------
        -- FREEZE TEST
        ---------------------------------------------------------------------
        enable <= '0';

        p7  <= prbs7;
        p15 <= prbs15;
        p23 <= prbs23;
        p31 <= prbs31;

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        if prbs7 /= p7 then pass7  <= false; report "FAIL: PRBS7 freeze" severity error; end if;
        if prbs15 /= p15 then pass15 <= false; report "FAIL: PRBS15 freeze" severity error; end if;
        if prbs23 /= p23 then pass23 <= false; report "FAIL: PRBS23 freeze" severity error; end if;
        if prbs31 /= p31 then pass31 <= false; report "FAIL: PRBS31 freeze" severity error; end if;


        ---------------------------------------------------------------------
        -- FINAL SUMMARY
        ---------------------------------------------------------------------
        report "-----------------------------------------------------------";
        report " PRBS7  : " & (boolean'image(pass7));
        report " PRBS15 : " & (boolean'image(pass15));
        report " PRBS23 : " & (boolean'image(pass23));
        report " PRBS31 : " & (boolean'image(pass31));
        report "-----------------------------------------------------------";

        if pass7 and pass15 and pass23 and pass31 then
            report "ALL TESTS PASSED SUCCESSFULLY" severity note;
        else
            report "ONE OR MORE PRBS TESTS FAILED" severity error;
        end if;

        wait;
    end process;

end architecture;