----------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Testbench Name: tc_framer_tb
-- DUT: tc_framer.vhd
-- Revisions:
--  V1.0: Created 11/02/2026 (generated using ChatGPT 5.2)
-- Comments:
--  Runs three core checks:
--   1) Reset behaviour (all outputs idle/0)
--   2) Frame start/valid/end timing + busy assertion
--   3) Payload_advance pulsing only during payload bits
--
-- NOTE: This TB does NOT verify CRC numeric correctness (you can add a golden CRC later).
-- It verifies the bit-level sequencing and handshakes.
-- Boilerplate code generated using ChatGPT 5.2 from V1.0 onwards
----------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tc_framer_tb is
end entity;

architecture tb of tc_framer_tb is
  constant CLK_PERIOD        : time    := 20 ns;
  constant G_SCID            : natural := 1;
  constant G_VCID            : natural := 0;
  constant G_PAYLOAD_BYTES   : natural := 4;  -- keep small for sim (4 bytes = 32 bits)
  constant PAYLOAD_BITS      : integer := integer(G_PAYLOAD_BYTES) * 8;

  signal clk             : std_logic := '0';
  signal reset           : std_logic := '0';
  signal enable          : std_logic := '0';
  signal bit_tick        : std_logic := '0';

  signal payload_bit_in  : std_logic := '0';
  signal payload_advance : std_logic;
  signal frame_bit_out   : std_logic;
  signal frame_valid     : std_logic;
  signal frame_start     : std_logic;
  signal frame_end       : std_logic;
  signal busy            : std_logic;

  -- simple deterministic payload pattern (MSB first)
  constant PAYLOAD_VEC : std_logic_vector(PAYLOAD_BITS-1 downto 0) := x"A5A5A5A5"; -- If G_PAYLOAD_BYTES is changes, MUST adapt this line

  signal pay_idx : integer range 0 to PAYLOAD_BITS := PAYLOAD_BITS-1;

  -- Count observed events
  signal start_count      : integer := 0;
  signal end_count        : integer := 0;
  signal valid_count      : integer := 0;
  signal payload_adv_cnt  : integer := 0;

begin
  -- Clock
  clk <= not clk after CLK_PERIOD/2;

  -- DUT
  dut : entity work.tc_framer(rtl)
    generic map (
      G_SCID          => G_SCID,
      G_VCID          => G_VCID,
      G_PAYLOAD_BYTES => G_PAYLOAD_BYTES
    )
    port map (
      clk             => clk,
      reset           => reset,
      enable          => enable,
      bit_tick        => bit_tick,
      payload_bit_in  => payload_bit_in,
      payload_advance => payload_advance,
      frame_bit_out   => frame_bit_out,
      frame_valid     => frame_valid,
      frame_start     => frame_start,
      frame_end       => frame_end,
      busy            => busy
    );

  -- Generate bit_tick: 1-cycle pulse every 1 symbol (here: every clock for simplicity)
  p_tick : process
  begin
    bit_tick <= '0';
    wait until rising_edge(clk);
    loop
      bit_tick <= '1';
      wait until rising_edge(clk);
      bit_tick <= '0';
      wait until rising_edge(clk);
    end loop;
  end process;

  -- Drive payload bits ONLY when DUT asks (payload_advance)
  p_payload : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        pay_idx <= PAYLOAD_BITS-1;
        payload_bit_in <= PAYLOAD_VEC(PAYLOAD_BITS-1);
      else
        if payload_advance = '1' then
          payload_bit_in <= PAYLOAD_VEC(pay_idx);
          if pay_idx = 0 then
            pay_idx <= PAYLOAD_BITS-1;   -- wrap for next frame
          else
            pay_idx <= pay_idx - 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Simple monitors / counters
  p_mon : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        start_count     <= 0;
        end_count       <= 0;
        valid_count     <= 0;
        payload_adv_cnt <= 0;
      else
        if frame_valid = '1' then
          valid_count <= valid_count + 1;
        end if;
        if frame_start = '1' then
          start_count <= start_count + 1;
        end if;
        if frame_end = '1' then
          end_count <= end_count + 1;
        end if;
        if payload_advance = '1' then
          payload_adv_cnt <= payload_adv_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  -- Stimulus + asserts
  stim : process
    constant HEADER_BITS : integer := 40;
    constant CRC_BITS    : integer := 16;
    constant TOTAL_BITS  : integer := HEADER_BITS + PAYLOAD_BITS + CRC_BITS;
  begin
    --------------------------------------------------------------------------
    -- Test 1: Reset
    --------------------------------------------------------------------------
    reset  <= '1';
    enable <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    assert busy = '0' report "RESET: busy should be 0" severity failure;
    assert frame_valid = '0' report "RESET: frame_valid should be 0" severity failure;
    assert frame_start = '0' report "RESET: frame_start should be 0" severity failure;
    assert frame_end   = '0' report "RESET: frame_end should be 0" severity failure;

    reset <= '0';
    wait until rising_edge(clk);
    report "TEST 1 PASSED: Reset ok" severity note;

    --------------------------------------------------------------------------
    -- Test 2: Start a frame
    --------------------------------------------------------------------------
    enable <= '1';

    -- Wait until we see frame_start
    wait until rising_edge(clk);
    while frame_start /= '1' loop
      wait until rising_edge(clk);
    end loop;

    assert busy = '1' report "Frame started but busy not asserted" severity failure;
    report "Frame start seen" severity note;

    --------------------------------------------------------------------------
    -- Test 3: Let one full frame run and check counts
    --------------------------------------------------------------------------
    -- Because bit_tick is every other clock, total time = TOTAL_BITS * 2 clocks
    wait for (TOTAL_BITS * 2 * CLK_PERIOD);

    assert end_count = 1
      report "Expected exactly 1 frame_end, got " & integer'image(end_count)
      severity failure;

    -- payload_advance should have pulsed exactly PAYLOAD_BITS times for one frame
    assert payload_adv_cnt = PAYLOAD_BITS
      report "Expected payload_advance pulses = " & integer'image(PAYLOAD_BITS) &
             ", got " & integer'image(payload_adv_cnt)
      severity failure;

    -- frame_valid should have asserted once per transmitted bit (header+payload+crc)
    assert valid_count = TOTAL_BITS
      report "Expected frame_valid count = " & integer'image(TOTAL_BITS) &
             ", got " & integer'image(valid_count)
      severity failure;

    report "TEST 2/3 PASSED: One full frame transmitted with correct handshakes" severity note;

    --------------------------------------------------------------------------
    -- Test 4: Disable and ensure no new frame starts
    --------------------------------------------------------------------------
    enable <= '0';
    wait for (50 * CLK_PERIOD);

    -- No new frame should start while enable=0
    assert start_count = 1
      report "Enable=0 but additional frame_start detected" severity failure;

    report "TEST 4 PASSED: enable=0 prevents new frames" severity note;

    report "ALL TESTS COMPLETED" severity note;
    wait;
  end process;

end architecture;
