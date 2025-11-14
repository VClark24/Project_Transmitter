library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_viv_mod is
end entity;

architecture tb of tb_viv_mod is

    -------------------------------------------------------------------------
    -- DUT generics
    -------------------------------------------------------------------------
    constant G_WIDTH : integer := 16;
    constant G_L     : integer := 8;

    -------------------------------------------------------------------------
    -- DUT I/O
    -------------------------------------------------------------------------
    signal clk     : std_logic := '0';
    signal rst_n   : std_logic := '0';
    signal enable  : std_logic := '1';
    signal mod_sel : std_logic := '0';     -- start in BPSK

    signal out_val : std_logic;
    signal out_i   : signed(G_WIDTH-1 downto 0);
    signal out_q   : signed(G_WIDTH-1 downto 0);

    -------------------------------------------------------------------------
    -- Clock period
    -------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

begin

    -------------------------------------------------------------------------
    -- Clock generator
    -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    -------------------------------------------------------------------------
    -- DUT instantiation
    -------------------------------------------------------------------------
    uut : entity work.viv_mod
        generic map(
            G_POLY_SEL => 1,                       -- PRBS7 for simulation speed
            G_SEED     => x"00000001",
            G_WIDTH    => G_WIDTH,
            G_L        => G_L
        )
        port map(
            clk      => clk,
            rst_n    => rst_n,
            enable   => enable,
            mod_sel  => mod_sel,
            out_val  => out_val,
            out_i    => out_i,
            out_q    => out_q
        );

    -------------------------------------------------------------------------
    -- Reset + Mode switching sequence
    -------------------------------------------------------------------------
    stim : process
    begin
        ---------------------------------------------------------------------
        -- Initial reset
        ---------------------------------------------------------------------
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';

        ---------------------------------------------------------------------
        -- Run BPSK for some time
        ---------------------------------------------------------------------
        report "=== BPSK MODE ===";
        mod_sel <= '0';
        wait for 2000 ns;

        ---------------------------------------------------------------------
        -- Switch to QPSK mode
        ---------------------------------------------------------------------
        report "=== QPSK MODE ===";
        mod_sel <= '1';
        wait for 3000 ns;

        ---------------------------------------------------------------------
        -- End sim
        ---------------------------------------------------------------------
        report "=== END OF SIM ===";
        wait;
    end process;

    -------------------------------------------------------------------------
    -- Output monitor
    -------------------------------------------------------------------------
    monitor : process(clk)
    begin
        if rising_edge(clk) then
            if out_val = '1' then
                report "I=" & integer'image(to_integer(out_i)) &
                       ", Q=" & integer'image(to_integer(out_q));
            end if;
        end if;
    end process;

end architecture;
