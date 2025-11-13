library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_v_up_zoh_iq is
end entity;

architecture sim of tb_v_up_zoh_iq is

    constant G_IN_WIDTH  : integer := 16;
    constant G_OUT_WIDTH : integer := 16;
    constant G_L         : integer := 16;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';

    signal in_val   : std_logic := '0';
    signal in_i     : signed(G_IN_WIDTH-1 downto 0) := (others=>'0');
    signal in_q     : signed(G_IN_WIDTH-1 downto 0) := (others=>'0');

    signal out_val  : std_logic;
    signal out_i    : signed(G_OUT_WIDTH-1 downto 0);
    signal out_q    : signed(G_OUT_WIDTH-1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin
    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    uut: entity work.v_up_zoh_iq
        generic map(
            G_IN_WIDTH  => G_IN_WIDTH,
            G_OUT_WIDTH => G_OUT_WIDTH,
            G_L         => G_L
        )
        port map(
            clk      => clk,
            rst_n    => rst_n,
            in_val   => in_val,
            in_i     => in_i,
            in_q     => in_q,
            out_val  => out_val,
            out_i    => out_i,
            out_q    => out_q
        );

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim : process
        procedure send_iq(i_s : integer; q_s : integer) is
        begin
            in_i   <= to_signed(i_s, G_IN_WIDTH);
            in_q   <= to_signed(q_s, G_IN_WIDTH);
            in_val <= '1';
            wait for CLK_PERIOD;
            in_val <= '0';
        end procedure;
    begin
        -- RESET
        rst_n <= '0';
        wait for 50 ns;
        rst_n <= '1';
        wait for CLK_PERIOD;

        -------------------------------------------------------------
        -- BPSK test (Q = 0)
        -------------------------------------------------------------
        report "Starting BPSK test";

        send_iq(+1000, 0);             -- Sample #1
        wait for G_L*CLK_PERIOD;

        send_iq(-2000, 0);             -- Sample #2
        wait for G_L*CLK_PERIOD;

        -------------------------------------------------------------
        -- QPSK test
        -------------------------------------------------------------
        report "Starting QPSK test";

        send_iq(+1000, +1000);         -- +45°
        wait for G_L*CLK_PERIOD;

        send_iq(+1000, -1000);         -- -45°
        wait for G_L*CLK_PERIOD;

        send_iq(-1000, +1000);         -- +135°
        wait for G_L*CLK_PERIOD;

        send_iq(-1000, -1000);         -- -135°
        wait for G_L*CLK_PERIOD;

        report "Simulation completed.";
        wait;
    end process;

end architecture;