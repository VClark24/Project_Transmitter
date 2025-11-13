library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity v_up_zoh_iq is
    generic(
        G_IN_WIDTH  : integer := 16;
        G_OUT_WIDTH : integer := 16;
        G_L         : integer := 16    -- upsample factor
    );
    port(
        clk      : in  std_logic;
        rst_n    : in  std_logic;      -- active-low reset

        in_val   : in  std_logic;
        in_i     : in  signed(G_IN_WIDTH-1 downto 0);
        in_q     : in  signed(G_IN_WIDTH-1 downto 0);

        out_val  : out std_logic;
        out_i    : out signed(G_OUT_WIDTH-1 downto 0);
        out_q    : out signed(G_OUT_WIDTH-1 downto 0)
    );
end entity;


architecture rtl of v_up_zoh_iq is
    signal hold_i : signed(G_OUT_WIDTH-1 downto 0);
    signal hold_q : signed(G_OUT_WIDTH-1 downto 0);

    signal cnt : integer range 0 to G_L-1 := 0;
begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            hold_i  <= (others => '0');
            hold_q  <= (others => '0');
            out_i   <= (others => '0');
            out_q   <= (others => '0');
            out_val <= '0';
            cnt     <= 0;

        elsif rising_edge(clk) then

            if in_val = '1' then
                -- New I/Q sample: capture and output immediately
                hold_i <= resize(in_i, G_OUT_WIDTH);
                hold_q <= resize(in_q, G_OUT_WIDTH);

                out_i  <= resize(in_i, G_OUT_WIDTH);
                out_q  <= resize(in_q, G_OUT_WIDTH);
                out_val <= '1';

                cnt <= 0;

            else
                -- Continue ZOH: repeat the held sample
                if cnt < G_L-1 then
                    cnt <= cnt + 1;

                    out_i  <= hold_i;
                    out_q  <= hold_q;
                    out_val <= '1';

                else
                    out_val <= '0';  -- waiting for next new sample
                end if;
            end if;

        end if;
    end process;

end architecture;
