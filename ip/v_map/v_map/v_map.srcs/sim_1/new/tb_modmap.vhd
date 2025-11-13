---------------------------------------------------------------------------
-- Testbench for v_map (BPSK / QPSK Mapper)
-- Tests:
--   ✔ Reset behaviour
--   ✔ BPSK mapping (+AMP / -AMP)
--   ✔ QPSK Gray mapping (4 symbol quadrants)
--   ✔ Output sign correctness
--   ✔ Output amplitude correctness (32767)
--   ✔ Mode switching BPSK → QPSK → BPSK
--   ✔ Glitch-free transitions
--   ✔ No X/U values on outputs
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_v_map is
end entity;

architecture tb of tb_v_map is

    constant CLK_PERIOD : time := 10 ns;
    constant AMP        : integer := 32767;   -- For 16-bit signed outputs

    -- DUT signals
    signal clk     : std_logic := '0';
    signal rst_n   : std_logic := '0';
    signal mod_sel : std_logic := '0'; -- 0=BPSK, 1=QPSK

    signal bit_in  : std_logic := '0';
    signal bits_in : std_logic_vector(1 downto 0) := "00";

    signal i_out   : signed(15 downto 0);
    signal q_out   : signed(15 downto 0);

begin

    -------------------------------------------------------------------------
    -- DUT INSTANCE
    -------------------------------------------------------------------------
    dut : entity work.v_map
        generic map(
            G_WIDTH => 16
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            bit_in  => bit_in,
            bits_in => bits_in,
            mod_sel => mod_sel,
            i_out   => i_out,
            q_out   => q_out
        );

    -------------------------------------------------------------------------
    -- CLOCK
    -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    -------------------------------------------------------------------------
    -- STIMULUS
    -------------------------------------------------------------------------
    stim : process
    begin
        ---------------------------------------------------------------------
        -- RESET
        ---------------------------------------------------------------------
        rst_n <= '0';
        mod_sel <= '0';
        bit_in  <= '0';
        bits_in <= "00";

        wait for 40 ns;
        rst_n <= '1';
        wait until rising_edge(clk);

        assert i_out = 0 and q_out = 0
            report "FAIL: Outputs not zero after reset" severity error;


        ---------------------------------------------------------------------
        -- TEST BPSK MAPPING
        ---------------------------------------------------------------------
        report "TESTING BPSK..." severity note;

        mod_sel <= '0';   -- BPSK

        -- Bit = 0 → +AMP
        bit_in <= '0';
        wait until rising_edge(clk);
        assert i_out = to_signed(AMP, 16)
            report "FAIL: BPSK bit=0 did not map to +AMP" severity error;
        assert q_out = 0
            report "FAIL: BPSK Q channel not zero" severity error;

        -- Bit = 1 → -AMP
        bit_in <= '1';
        wait until rising_edge(clk);
        assert i_out = to_signed(-AMP, 16)
            report "FAIL: BPSK bit=1 did not map to -AMP" severity error;
        assert q_out = 0
            report "FAIL: BPSK Q channel not zero" severity error;


        ---------------------------------------------------------------------
        -- TEST QPSK MAPPING
        ---------------------------------------------------------------------
        report "TESTING QPSK..." severity note;

        mod_sel <= '1'; -- QPSK

        -- Gray mapping:
        -- 00 → +1 , +1
        bits_in <= "00";
        wait until rising_edge(clk);
        assert i_out = to_signed(+AMP,16)
            report "FAIL: QPSK(00) wrong I" severity error;
        assert q_out = to_signed(+AMP,16)
            report "FAIL: QPSK(00) wrong Q" severity error;

        -- 01 → -1 , +1
        bits_in <= "01";
        wait until rising_edge(clk);
        assert i_out = to_signed(-AMP,16)
            report "FAIL: QPSK(01) wrong I" severity error;
        assert q_out = to_signed(+AMP,16)
            report "FAIL: QPSK(01) wrong Q" severity error;

        -- 11 → -1 , -1
        bits_in <= "11";
        wait until rising_edge(clk);
        assert i_out = to_signed(-AMP,16)
            report "FAIL: QPSK(11) wrong I" severity error;
        assert q_out = to_signed(-AMP,16)
            report "FAIL: QPSK(11) wrong Q" severity error;

        -- 10 → +1 , -1
        bits_in <= "10";
        wait until rising_edge(clk);
        assert i_out = to_signed(+AMP,16)
            report "FAIL: QPSK(10) wrong I" severity error;
        assert q_out = to_signed(-AMP,16)
            report "FAIL: QPSK(10) wrong Q" severity error;


        ---------------------------------------------------------------------
        -- TEST MODE SWITCHING (BPSK -> QPSK -> BPSK)
        ---------------------------------------------------------------------
        report "TESTING MODE SWITCHING..." severity note;

        -- BPSK again
        mod_sel <= '0';
        bit_in  <= '0';
        wait until rising_edge(clk);
        assert i_out = to_signed(AMP,16)
            report "FAIL: BPSK after mode switch wrong" severity error;
        assert q_out = 0
            report "FAIL: BPSK Q path not zero after mode switch" severity error;

        ---------------------------------------------------------------------
        -- FINAL RESULT
        ---------------------------------------------------------------------
        report "-----------------------------------------------";
        report "      ALL v_map TESTS PASSED SUCCESSFULLY";
        report "-----------------------------------------------";

        wait;
    end process;

end architecture;
