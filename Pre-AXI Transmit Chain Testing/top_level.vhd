-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Top Level
-- Revisions:
--  V1.0: Created 26/01/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
--  V1.1: 11/02/2026 to incorporate telecommand selection (for framing and encoding)
--  V1.2: 11/02/2026 add safe waveform switching (hold applied waveform during TC busy) 
--  V1.3: 16/02/2026 add telecommand framing debug
--  NOTE: Due to subequent testing phases, this top level file may no longer work with the 
--  current IP cores, as they have been adapted due to subsequent testing. This is to give an 
--  indication of the testing strategy before integration into the AD9361 reference design.
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity top_level is
  generic (
    G_WIDTH           : integer := 16;
    G_CLKS_PER_SYMBOL : integer := 10
  );
  port (
    clk   : in std_logic;
    reset : in std_logic; -- Active HIGH
    enable: in std_logic;
    mute  : in std_logic := '0';

    waveform_sel : in unsigned(2 downto 0) := "010"; -- Beacon default (GUI request)

    i_out : out signed(G_WIDTH-1 downto 0);
    q_out : out signed(G_WIDTH-1 downto 0);

    prbs_dbg : out std_logic;

    -- TC framing debug
    tc_busy_dbg    : out std_logic;
    tc_bit_dbg     : out std_logic;
    tc_bit_vld_dbg : out std_logic;
    tc_sof_dbg     : out std_logic;
    tc_eof_dbg     : out std_logic;
    
    -- TM framing debug
    tm_busy_dbg     : out std_logic;
    tm_bit_dbg      : out std_logic;
    tm_bit_vld_dbg  : out std_logic;
    tm_sof_dbg      : out std_logic;
    tm_eof_dbg      : out std_logic;

    symbol_en_dbg  : out std_logic
  );
end entity top_level;

architecture rtl of top_level is

  signal symbol_en      : std_logic := '0';
  signal half_symbol_en : std_logic := '0';

  signal run         : std_logic := '0';
  signal waveform_act: unsigned(2 downto 0) := "010";

  signal prbs_bit    : std_logic := '0';
  signal prbs_adv_en : std_logic := '0';
  signal prbs_state_dbg : std_logic_vector(22 downto 0);

  signal tc_sel      : std_logic := '0';
  signal tm_sel      : std_logic := '0';

  signal tc_enable   : std_logic := '0';
  signal tm_enable   : std_logic := '0';

  signal tc_busy     : std_logic := '0';
  signal tm_busy     : std_logic := '0';

  signal tc_bit      : std_logic := '0';
  signal tm_bit      : std_logic := '0';

  signal tc_payload_adv : std_logic := '0';
  signal tm_payload_adv : std_logic := '0';

  signal tc_frame_valid : std_logic := '0';
  signal tc_frame_start : std_logic := '0';
  signal tc_frame_end   : std_logic := '0';

  signal tm_frame_valid : std_logic := '0';
  signal tm_frame_start : std_logic := '0';
  signal tm_frame_end   : std_logic := '0';

  signal tm_header_dbg  : std_logic_vector(47 downto 0) := (others => '0');

  signal tx_bit_sym  : std_logic := '0';

  signal i_int : signed(G_WIDTH - 1 downto 0) := (others => '0');
  signal q_int : signed(G_WIDTH - 1 downto 0) := (others => '0');

begin

  -- Global run gate (no bit slipping)
  run <= enable and (not mute);

  -- TC/TM selects are based on APPLIED waveform (NOT raw GUI waveform)
  tc_sel <= '1' when waveform_act = "000" else '0';
  tm_sel <= '1' when waveform_act = "001" else '0';

  tc_enable <= run and tc_sel;
  tm_enable <= run and tm_sel;

  -- Safe waveform switching:
  -- Apply GUI waveform only when TC framer is NOT busy, and at a symbol boundary.
  p_waveform_apply : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        waveform_act <= "010";  -- default applied waveform
      elsif (symbol_en = '1') and
            (run = '1') and
            (tc_busy = '0') and
            (tm_busy = '0') then
        waveform_act <= waveform_sel;
      end if;
    end if;
  end process;

  -- Symbol Timing (Provides strobes for mapper / framer)
  u_symboltimer : entity work.symbol_timer(rtl)
    generic map (
      G_CLKS_PER_SYMBOL => G_CLKS_PER_SYMBOL
    )
    port map (
      clk           => clk,
      reset         => reset,
      enable        => run,       -- keep symbol timing aligned with run
      symbol_en     => symbol_en,
      half_symbol_en=> half_symbol_en,
      mute          => '0'
    );

  symbol_en_dbg <= symbol_en;

  -- PRBS Advance Policy
-- TC (BPSK framed): advance only when TC consumes a payload bit
-- TM (BPSK framed): advance only when TM consumes a payload bit
-- FHSS OQPSK ("011"): advance on symbol_en OR half_symbol_en
-- Otherwise (raw/unframed BPSK): advance once per symbol
prbs_adv_en <= (tc_payload_adv and run) when (tc_sel = '1') else
              (tm_payload_adv and run) when (tm_sel = '1') else
              (run and (symbol_en or half_symbol_en)) when (waveform_act = "011") else
              (run and symbol_en);
              
  -- PRBS23
  u_prbs23 : entity work.prbs23(rtl)
    port map (
      clk         => clk,
      reset       => reset,
      enable      => prbs_adv_en,
      prbs_output => prbs_bit,
      state_dbg   => prbs_state_dbg
    );

  prbs_dbg <= prbs_bit;

  -- Telecommand Framing
  u_tcframer : entity work.tc_framer(rtl)
    generic map (
      G_SCID          => 1,
      G_VCID          => 0,
      G_PAYLOAD_BYTES => 16
    )
    port map (
      clk             => clk,
      reset           => reset,
      enable          => tc_enable,
      bit_tick        => symbol_en,
      payload_bit_in  => prbs_bit,
      frame_bit_out   => tc_bit,
      payload_advance => tc_payload_adv,

      frame_valid     => tc_frame_valid,
      frame_start     => tc_frame_start,
      frame_end       => tc_frame_end,
      busy            => tc_busy
    );

  -- TC debug
  tc_busy_dbg    <= tc_busy;
  tc_bit_dbg     <= tc_bit;
  tc_bit_vld_dbg <= tc_frame_valid;
  tc_sof_dbg     <= tc_frame_start;
  tc_eof_dbg     <= tc_frame_end;

  -- Telemetry Framing
  u_tmframer : entity work.tm_framer(rtl)
    generic map (
      G_SCID          => 1,
      G_VCID          => 0,
      G_PAYLOAD_BYTES => 16
    )
    port map (
      clk             => clk,
      reset           => reset,
      enable          => tm_enable,
      bit_tick        => symbol_en,
      payload_bit_in  => prbs_bit,

      payload_advance => tm_payload_adv,
      frame_bit_out   => tm_bit,

      frame_valid     => tm_frame_valid,
      frame_start     => tm_frame_start,
      frame_end       => tm_frame_end,
      busy            => tm_busy,
      header_dbg      => tm_header_dbg
    );

  -- TM debug
  tm_busy_dbg    <= tm_busy;
  tm_bit_dbg     <= tm_bit;
  tm_bit_vld_dbg <= tm_frame_valid;
  tm_sof_dbg     <= tm_frame_start;
  tm_eof_dbg     <= tm_frame_end;

  -- Symbol-aligned bit latch (feeds mapper with a stable bit for the whole symbol)
  p_txbit_latch : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        tx_bit_sym <= '0';
      elsif run = '1' then
        if symbol_en = '1' then
          if tc_sel = '1' then
            tx_bit_sym <= tc_bit;
          elsif tm_sel = '1' then
            tx_bit_sym <= tm_bit;
          else
            tx_bit_sym <= prbs_bit;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Modulation Mapper (BPSK/OQPSK selection using APPLIED waveform)
  u_mapper : entity work.mapper(rtl)
    generic map (
      G_WIDTH => G_WIDTH
    )
    port map (
      clk            => clk,
      reset          => reset,
      enable         => run,
      symbol_en       => symbol_en,
      half_symbol_en  => half_symbol_en,
      prbs_in         => tx_bit_sym,
      waveform_sel    => waveform_act,
      i_out           => i_int,
      q_out           => q_int
    );

  i_out <= (others => '0') when (mute = '1' or enable = '0') else i_int;
  q_out <= (others => '0') when (mute = '1' or enable = '0') else q_int;

end architecture rtl;
