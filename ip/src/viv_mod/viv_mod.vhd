-- 
-- viv_mod: PRBS -> v_map -> v_up_zoh_iq
--
--  * PRBS generates a serial bit stream.
--  * For BPSK: bit_in = PRBS bit.
--  * For QPSK: a 2-bit shift register builds bits_in from successive PRBS bits.
--  * v_up_zoh_iq does zero-order hold with factor G_L using a symbol-valid
--    strobe generated inside this block.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity viv_mod is
    generic(
        G_POLY_SEL : integer := 1;                 -- PRBS7/15/23/31 selector
        G_SEED     : std_logic_vector(31 downto 0) := x"00000001";
        G_WIDTH    : integer := 16;                -- I/Q width
        G_L        : integer := 8                 -- upsample factor
    );
    port(
        clk      : in  std_logic;
        rst_n    : in  std_logic;                  -- active-low reset
        enable   : in  std_logic := '1';

        mod_sel  : in  std_logic;                  -- 0 = BPSK, 1 = QPSK

        out_val  : out std_logic;                  -- valid at DAC rate
        out_i    : out signed(G_WIDTH-1 downto 0);
        out_q    : out signed(G_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of viv_mod is

    -- PRBS + QPSK bit-pair builder
    signal prbs_bit   : std_logic;
    signal qpsk_bits  : std_logic_vector(1 downto 0) := (others => '0');

    -- Mapper outputs (symbol-rate I/Q)
    signal map_i, map_q : signed(G_WIDTH-1 downto 0);

    -- Symbol-valid for upsampler (one pulse every G_L clocks)
    signal sample_cnt : integer range 0 to G_L-1 := 0;
    signal sym_valid  : std_logic := '0';

begin

    -------------------------------------------------------------------------
    -- PRBS generator
    -------------------------------------------------------------------------
    u_prbs : entity work.prbs_gen
        generic map(
            G_POLY_SEL => G_POLY_SEL,
            G_SEED     => G_SEED
        )
        port map(
            clk      => clk,
            rst_n    => rst_n,
            enable   => enable,      -- run continuously
            prbs_out => prbs_bit
        );

    -------------------------------------------------------------------------
    -- Build 2-bit word for QPSK from successive PRBS bits
    -------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            qpsk_bits <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                -- shift left, new PRBS bit into LSB
                qpsk_bits <= qpsk_bits(0) & prbs_bit;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Modulation mapper (BPSK / QPSK)
    -------------------------------------------------------------------------
    u_map : entity work.v_map
        generic map(
            G_WIDTH => G_WIDTH
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            bit_in  => prbs_bit,     -- used in BPSK mode
            bits_in => qpsk_bits,    -- used in QPSK mode
            mod_sel => mod_sel,

            i_out   => map_i,
            q_out   => map_q
        );

    -------------------------------------------------------------------------
    -- Generate symbol-valid pulse every G_L clocks
    -- (this drives the ZOH upsampler's in_val)
    -------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sample_cnt <= 0;
            sym_valid  <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if sample_cnt = G_L-1 then
                    sample_cnt <= 0;
                    sym_valid  <= '1';   -- one-cycle strobe
                else
                    sample_cnt <= sample_cnt + 1;
                    sym_valid  <= '0';
                end if;
            else
                sym_valid <= '0';
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Zero-Order Hold IQ Upsampler
    -------------------------------------------------------------------------
    u_up : entity work.v_up_zoh_iq
        generic map(
            G_IN_WIDTH  => G_WIDTH,
            G_OUT_WIDTH => G_WIDTH,
            G_L         => G_L
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,

            in_val  => sym_valid,  -- 1 clock per new symbol
            in_i    => map_i,
            in_q    => map_q,

            out_val => out_val,    -- sample-rate valid
            out_i   => out_i,
            out_q   => out_q
        );

end architecture;