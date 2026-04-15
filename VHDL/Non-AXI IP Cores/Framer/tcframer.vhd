-----------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Telecommand Framing Block
-- Revisions:
--  V1.0: Created 09/02/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
-- Comments:
--   Compatible with CCSDS 232.0-B-4: TC Space Data Link Protocol
--   Payload size 14 bit. Feeds into BCH(63, 56) so payload size should be a multiple of 7.
--      BCH unit is now 1/4 of frame worth of information
-----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tc_framer is
  generic (
    G_SCID          : natural range 0 to 1023 := 1;   -- 10-bit SCID
    G_VCID          : natural range 0 to 63   := 0;   -- 6-bit VCID
    G_PAYLOAD_BYTES : natural                 := 14  -- choose a starting payload size
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;
    enable : in std_logic;
    bit_tick : in std_logic; -- connected to symbol_en (from symbol_time.vhd)
    payload_bit_in : in std_logic; -- connected to prbs_output (from prbs23.vhd)
    downstream_ready : in std_logic;

    payload_advance : out std_logic := '0'; -- connected to tc_enable_o path enable controller
    frame_bit_out : out std_logic := '0'; -- connected to BCH encoder

    -- For debugging
    frame_valid : out std_logic := '0'; -- high when frame_bit_out is valid on bit_tick
    frame_start : out std_logic := '0'; -- high on first header bit
    frame_end : out std_logic := '0'; -- high on last bit
    busy : out std_logic := '0' -- high when mid-frame
  );
end entity tc_framer;

architecture rtl of tc_framer is
  constant header_bytes : integer := 5;
  constant crc_bits : integer := 16;
  constant crc_bytes : integer := 2;
  constant payload_bits : integer := G_PAYLOAD_BYTES * 8;
  constant total_bytes : integer := header_bytes + G_PAYLOAD_BYTES + crc_bytes;
  constant c_fieldlen : integer := total_bytes - 1;
  constant crc_init : std_logic_vector(15 downto 0) := (others => '1');

  type tcframe_fsm is (IDLE, SEND_HEADER, SEND_PAYLOAD, SEND_CRC);              -- Four-state FSM
  signal state : tcframe_fsm := IDLE;
  signal header_reg : std_logic_vector(39 downto 0);
  signal seq_count : unsigned(7 downto 0) := (others => '0');
  signal hdr_idx : integer range 0 to 39 := 39;
  signal pay_idx : integer range 0 to payload_bits - 1 := 0;
  signal crc_reg : std_logic_vector(15 downto 0) := crc_init;
  signal crc_shift : std_logic_vector(15 downto 0);
  signal crc_idx : integer range 0 to 15 := 15;
  signal state_code : std_logic_vector(1 downto 0);
  signal frame_start_pending : std_logic := '0';
begin
  assert (c_fieldlen <= 1023) report "10-bit length overflow" severity failure;         -- These asserts are not strictly necessary but help  to prevent incorrect/unsafe code from running
  assert (G_PAYLOAD_BYTES > 0) report "Payload must be > 0 bytes" severity failure;
  assert (payload_bits > 0) report "Payload bits must be > 0" severity failure;

  with state select
    state_code <= "00" when IDLE,
                  "01" when SEND_HEADER,
                  "10" when SEND_PAYLOAD,
                  "11" when SEND_CRC;     -- To assist with debugging in simulation

  process(clk)
    variable din : std_logic;
    variable fb : std_logic;
    variable crc_next : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        header_reg <= (others => '0');
        seq_count <= (others => '0');
        state <= IDLE;
        hdr_idx <= 39;
        pay_idx <= 0;
        crc_idx <= 15;
        crc_reg <= crc_init;
        crc_shift <= (others => '0');
        frame_bit_out <= '0';
        payload_advance <= '0';
        frame_valid <= '0';
        frame_start <= '0';
        frame_end <= '0';
        busy <= '0';
        frame_start_pending <= '0';
      else
        -- pulse outputs only
        frame_valid <= '0';
        frame_start <= '0';
        frame_end <= '0';
        payload_advance <= '0';

        if state = IDLE then
          busy <= '0';
        else
          busy <= '1';
        end if;

        if bit_tick = '1' and downstream_ready = '1' then
          case state is
            when IDLE =>
              if enable = '1' then
                header_reg <= "00" & '0' & '0' & "00" &
                              std_logic_vector(to_unsigned(G_SCID, 10)) &
                              std_logic_vector(to_unsigned(G_VCID, 6)) &
                              std_logic_vector(to_unsigned(c_fieldlen, 10)) &
                              std_logic_vector(seq_count);              -- For header design and justification, see Section 6.1.3.2 in the Final Report PDF
                hdr_idx <= 39;
                crc_idx <= 15;
                pay_idx <= payload_bits - 1;
                crc_reg <= crc_init;
                frame_start_pending <= '1';
                state <= SEND_HEADER;
              end if;

            when SEND_HEADER =>
              frame_bit_out <= header_reg(hdr_idx);
              frame_valid <= '1';

              if frame_start_pending = '1' then
                frame_start <= '1';
                frame_start_pending <= '0';
              end if;

              din := header_reg(hdr_idx);
              fb := crc_reg(15) xor din;
              crc_next := crc_reg(14 downto 0) & '0';
              if fb = '1' then
                crc_next := crc_next xor x"1021";
              end if;
              crc_reg <= crc_next;

              if hdr_idx = 0 then
                pay_idx <= payload_bits - 1;
                state <= SEND_PAYLOAD;
              else
                hdr_idx <= hdr_idx - 1;
              end if;

            when SEND_PAYLOAD =>
              frame_bit_out <= payload_bit_in;
              frame_valid <= '1';
              payload_advance <= '1';

              din := payload_bit_in;
              fb := crc_reg(15) xor din;
              crc_next := crc_reg(14 downto 0) & '0';
              if fb = '1' then
                crc_next := crc_next xor x"1021";
              end if;
              crc_reg <= crc_next;

              if pay_idx = 0 then
                crc_shift <= crc_next;
                crc_idx <= 15;
                state <= SEND_CRC;
              else
                pay_idx <= pay_idx - 1;
              end if;

            when SEND_CRC =>
              frame_bit_out <= crc_shift(crc_idx);
              frame_valid <= '1';

              if crc_idx = 0 then
                crc_idx <= 15;
                frame_end <= '1';
                seq_count <= seq_count + 1;
                state <= IDLE;
              else
                crc_idx <= crc_idx - 1;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
