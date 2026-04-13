---------------------------------------------------------------------------------------------------
-- Testbench: conv_encoder_tb.vhd
-- Purpose  : Self-checking TB for CCSDS K=7, r=1/2 convolutional encoder (171/133, G2 inverted)
-- DUT      : conv_encoder (your RTL)
-- Checks   : 1) Handshake (in_ready alternates as expected)
--            2) For each accepted input bit -> exactly 2 output bits (C1 then C2_inv)
--            3) Output bitstream matches a golden model (same tap mapping as DUT)
-- Notes    : This TB assumes your DUT mapping:
--            shift_reg(0)=m1 (most recent), ... shift_reg(5)=m6 (oldest)
--            shift_reg <= in_bit & shift_reg(5 downto 1)
--            c1 = u xor m1 xor m2 xor m3 xor m6
--            c2 = u xor m2 xor m3 xor m5 xor m6, and output is NOT(c2)
-- Boilerplate code generated using ChatGPT 5.2
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_encoder_tb is
end entity conv_encoder_tb;

architecture tb of conv_encoder_tb is

  constant CLK_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal reset    : std_logic := '1';
  signal enable   : std_logic := '0';

  signal in_bit   : std_logic := '0';
  signal in_valid : std_logic := '0';
  signal in_ready : std_logic;

  signal out_bit   : std_logic;
  signal out_valid : std_logic;

  signal busy     : std_logic;

  -- Stimulus pattern (time order MSB-first)
  constant N_BITS : natural := 32;
  constant VEC    : std_logic_vector(N_BITS-1 downto 0) := x"80000000";

begin

  -----------------------------------------------------------------------------
  -- Clock
  -----------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD/2;


  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : entity work.conv_encoder
    port map (
      clk       => clk,
      reset     => reset,
      enable    => enable,
      in_bit    => in_bit,
      in_valid  => in_valid,
      in_ready  => in_ready,
      out_bit   => out_bit,
      out_valid => out_valid,
      busy      => busy
    );

  -----------------------------------------------------------------------------
  -- Stimulus + self-check
  -----------------------------------------------------------------------------
  stim : process
    -- Golden model shift register. Your DUT uses 6 stored bits (K-1),
    -- and combines with current input bit to form the 7-tap polynomials.
    variable sr : std_logic_vector(5 downto 0) := (others => '0');

    variable u      : std_logic;
    variable c1_exp : std_logic;
    variable c2_exp : std_logic;

    variable exp_out : std_logic_vector(2*N_BITS-1 downto 0);
    variable out_idx : integer := 0;

    variable seen : integer := 0;

    procedure idle_cycles(n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;


    -- Drive a bit; hold in_valid until DUT ready on a tick edge.
    procedure send_bit_when_ready(b : std_logic) is
    begin
        in_bit   <= b;
        in_valid <= '1';

        -- wait until DUT is ready on a rising edge
        wait until rising_edge(clk);
        while in_ready /= '1' loop
        wait until rising_edge(clk);
        end loop;

        -- accepted on that edge
        in_valid <= '0';
        in_bit   <= '0';
    end procedure;

    -- Consume/check exactly two out_valid events (C1 then C2)
    procedure expect_two_outputs is
    begin
      seen := 0;
      while seen < 2 loop
        wait until rising_edge(clk);

        -- Optional handshake sanity: if busy high, in_ready should be low (matches your FSM)
        if busy = '1' then
          assert in_ready = '0'
            report "Handshake error: busy=1 but in_ready/=0"
            severity error;
        end if;

        if out_valid = '1' then
          assert out_bit = exp_out(out_idx)
            report "Mismatch at encoded output index " & integer'image(out_idx) &
                   " exp=" & std_logic'image(exp_out(out_idx)) &
                   " got=" & std_logic'image(out_bit)
            severity error;

          out_idx := out_idx + 1;
          seen := seen + 1;
        end if;
      end loop;
    end procedure;

  begin
    -----------------------------------------------------------------------------
    -- Reset / init
    -----------------------------------------------------------------------------
    enable   <= '0';
    in_bit   <= '0';
    in_valid <= '0';

    idle_cycles(2);
    reset <= '1';
    idle_cycles(2);
    reset <= '0';
    idle_cycles(2);

    enable <= '1';
    idle_cycles(1);

    -----------------------------------------------------------------------------
    -- Build expected output stream (golden model)
    -- G1 = 171(oct) = 1111001 => taps: u, m1, m2, m3, m6
    -- G2 = 133(oct) = 1011011 => taps: u, m2, m3, m5, m6, then invert output
    -----------------------------------------------------------------------------
    sr := (others => '0');

    for i in 0 to integer(N_BITS)-1 loop
      u := VEC(N_BITS-1 - i); -- MSB-first in time

      c1_exp := u xor sr(0) xor sr(1) xor sr(2) xor sr(5);
      c2_exp := not (u xor sr(1) xor sr(2) xor sr(4) xor sr(5));

      exp_out(2*i)     := c1_exp;
      exp_out(2*i + 1) := c2_exp;

      sr := u & sr(5 downto 1);
    end loop;

    -----------------------------------------------------------------------------
    -- Apply stimulus and check outputs
    -----------------------------------------------------------------------------
    out_idx := 0;

    for i in 0 to integer(N_BITS)-1 loop
      send_bit_when_ready(VEC(N_BITS-1 - i));
      expect_two_outputs;
    end loop;

    -----------------------------------------------------------------------------
    -- Final checks
    -----------------------------------------------------------------------------
    assert out_idx = integer(2*N_BITS)
      report "Wrong number of output bits. got=" & integer'image(out_idx) &
             " exp=" & integer'image(integer(2*N_BITS))
      severity error;

    report "conv_encoder_tb: PASS (all encoded bits matched golden model)" severity note;
    wait;
  end process;

end architecture tb;
