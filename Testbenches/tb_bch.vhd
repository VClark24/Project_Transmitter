---------------------------------------------------------------------------------------------------
-- Minimal Testbench: bch_encoder_tb_min.vhd
-- Goal    : Prove the *first systematic bit* is not being lost, with clean stimulus timing.
-- Method  : Send a trivial vector where bit0 is unmistakable, and just observe waves:
--           1) all zeros except first transmitted bit = '1'
--           2) drive bits with setup on falling edge, sample on rising edge
-- Notes   : This TB is NOT self-checking. It's meant for waveform debug.
-- Boilerplate code written using ChatGPT 5.2
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bch_encoder_tb_min is
end entity;

architecture tb of bch_encoder_tb_min is

  constant G_K_INFO_BITS   : natural := 56;
  constant G_R_PARITY_BITS : natural := 7;

  constant CLK_PERIOD : time := 10 ns;

  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal enable     : std_logic := '0';
  signal data_in    : std_logic := '0';
  signal data_valid : std_logic := '0';

  signal coded_bit_out : std_logic;
  signal code_valid    : std_logic;
  signal busy          : std_logic;

  -- Choose which direction you want to send bits in time.
  -- true  => MSB-first (bit 55 is first)
  -- false => LSB-first (bit 0 is first)
  constant C_SEND_MSB_FIRST : boolean := false;

  -- Debug pattern: only the FIRST transmitted bit is '1', all others '0'.
  -- If C_SEND_MSB_FIRST=false, then INFO_BITS(0)=1 means first bit in time is 1.
  -- If C_SEND_MSB_FIRST=true,  then INFO_BITS(55)=1 means first bit in time is 1.
  constant INFO_BITS : std_logic_vector(G_K_INFO_BITS-1 downto 0) :=
    (others => '0');

  function get_info_bit(v : std_logic_vector; i : natural) return std_logic is
    variable idx : integer;
  begin
    if C_SEND_MSB_FIRST then
      idx := integer(v'left) - integer(i);
    else
      idx := integer(v'right) + integer(i);
    end if;
    return v(idx);
  end function;

begin

  -- Clock
  clk <= not clk after CLK_PERIOD/2;

  -- DUT
  dut : entity work.bch_encoder
    generic map (
      G_K_INFO_BITS   => G_K_INFO_BITS,
      G_R_PARITY_BITS => G_R_PARITY_BITS
    )
    port map (
      clk           => clk,
      rst           => rst,
      enable        => enable,
      data_in       => data_in,
      data_valid    => data_valid,
      coded_bit_out => coded_bit_out,
      code_valid    => code_valid,
      busy          => busy
    );

  stim : process
    -- Make a mutable local copy so we can set the "first bit" cleanly
    variable bits_v : std_logic_vector(G_K_INFO_BITS-1 downto 0);
    procedure idle_cycles(n : natural) is
    begin
      for k in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- Clean timing: setup on falling edge, sampled on rising edge
    procedure drive_bit(b : std_logic) is
    begin
      wait until falling_edge(clk);
      data_in    <= b;
      data_valid <= '1';

      wait until rising_edge(clk);  -- sampled here

      wait until falling_edge(clk);
      data_valid <= '0';
      data_in    <= '0';
    end procedure;

  begin
    --------------------------------------------------------------------------
    -- Init / reset
    --------------------------------------------------------------------------
    enable     <= '0';
    data_in    <= '0';
    data_valid <= '0';

    idle_cycles(2);
    rst <= '1';
    idle_cycles(2);
    rst <= '0';
    idle_cycles(2);

    enable <= '1';
    idle_cycles(2);

    --------------------------------------------------------------------------
    -- Build the simple pattern: FIRST transmitted bit = 1, rest 0
    --------------------------------------------------------------------------
    bits_v := x"0123346A89FFFD";
    -- if C_SEND_MSB_FIRST then
     -- bits_v(G_K_INFO_BITS-1) := '1'; -- first in time is MSB
    --else
      --its_v(0) := '1';              -- first in time is LSB
    --end if;

    -- report "Sending 56 info bits. First-in-time bit = 1. C_SEND_MSB_FIRST=" &
          -- boolean'image(C_SEND_MSB_FIRST)
           --severity note;/*

    --------------------------------------------------------------------------
    -- Drive 56 bits
    --------------------------------------------------------------------------
    for i in 0 to G_K_INFO_BITS-1 loop
      drive_bit(get_info_bit(bits_v, i));
    end loop;

    --------------------------------------------------------------------------
    -- Let parity drain out (at least 10 cycles)
    --------------------------------------------------------------------------
    idle_cycles(20);

    report "Done. Inspect waveform: coded_bit_out should show first systematic bit=1 aligned with first code_valid." severity note;
    wait;
  end process;

end architecture;
