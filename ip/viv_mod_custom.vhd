-- #########################################################################
-- File: viv_mod.vhd
-- Desc: Top-level chaining v_prbs -> v_map -> v_up
-- #########################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity viv_mod is
    generic(
        G_POLY  : integer := 7;     -- PRBS polynomial (7, 31 etc)
        G_SEED  : natural := 1;     -- PRBS seed
        G_MOD   : integer := 1;     -- 1 = BPSK, 2 = QPSK
        G_WIDTH : integer := 16;    -- I/Q output width
        G_L     : integer := 4      -- Upsample factor
    );
    port(
        clk     : in  std_logic;
        rst_n   : in  std_logic;            -- active LOW reset
        enable  : in  std_logic := '1';

        i_out   : out signed(G_WIDTH-1 downto 0);
        q_out   : out signed(G_WIDTH-1 downto 0);
        v_out   : out std_logic             -- valid strobe after upsampling
    );
end entity;

architecture rtl of viv_mod is

    -- PRBS outputs
    signal prbs_bit  : std_logic;
    signal prbs_val  : std_logic;

    -- Mapper outputs
    signal map_i, map_q : signed(G_WIDTH-1 downto 0);
    signal map_val      : std_logic;

    -- Upsampler outputs
    signal up_i, up_q : signed(G_WIDTH-1 downto 0);
    signal up_val     : std_logic;

begin
    -------------------------------------------------------------------------
    -- PRBS generator
    -------------------------------------------------------------------------
    u_prbs : entity work.v_prbs
        generic map(
            G_POLY => G_POLY,
            G_SEED => G_SEED,
            G_MOD  => G_MOD
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            enable  => enable,
            prbs_o  => prbs_bit,
            v_o     => prbs_val
        );

    -------------------------------------------------------------------------
    -- Modulation mapper (BPSK / QPSK)
    -------------------------------------------------------------------------
    u_map : entity work.v_map
        generic map(
            G_WIDTH => G_WIDTH,
            G_MOD   => G_MOD
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            v_i     => prbs_val,
            prbs_i  => prbs_bit,
            i_o     => map_i,
            q_o     => map_q,
            v_o     => map_val
        );

    -------------------------------------------------------------------------
    -- Upsampler (zero-order-hold)
    -------------------------------------------------------------------------
    u_up : entity work.v_up
        generic map(
            G_WIDTH => G_WIDTH,
            G_L     => G_L
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            v_i     => map_val,
            i_i     => map_i,
            q_i     => map_q,
            i_o     => up_i,
            q_o     => up_q,
            v_o     => up_val
        );

    -------------------------------------------------------------------------
    -- Outputs
    -------------------------------------------------------------------------
    i_out <= up_i;
    q_out <= up_q;
    v_out <= up_val;

end architecture;
