-----------------------------------------------------------------------------------------------------------------------------
-- VHDL Compatibility: IEEE Std 1076-2008
-- Organisation: Southampton Solent University
-- Engineer: Vivienne Clark
-- Module Name: Telemetry Framing Block
-- Revisions:
--  V1.0: Created 11/02/2026 in GitHub (https://github.com/VClark24/Project_Transmitter)
--  V1.2: Created 16/02/2026 Vivado stand-alone adaptations
--  V1.3: 23/02/2026 to incorporate ASM
--  V1.4: 23/02/2026 to incorporate handshaking
-- Comments:
--   Compatible with CCSDS 132.0-B-3: TM Space Data Link Protocol and CCSDS 131.0-B-5: TM Synchronization and Channel Coding
--   This is a continuous streaming code, BCH for telecommand is, in constrast, a block code
----------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tm_framer is
  generic (
    G_SCID          : natural range 0 to 1023 := 1;   -- 10-bit SCID
    G_VCID          : natural range 0 to 7   := 0;   -- 3-bit VCID
    G_PAYLOAD_BYTES : natural                 := 16   -- choose a starting payload size
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;
    enable : in std_logic;
    bit_tick : in std_logic; -- connected to symbol_en (from symbol_timer.vhd)
    downstream_ready : in std_logic; -- (from conv.vhd)
    payload_bit_in : in std_logic; -- connected to prbs_output (from prbs23.vhd)

    payload_advance : out std_logic; -- connected to enable (from prbs23.vhd)
    frame_bit_out : out std_logic; -- connected to prbs_in (from mapper.vhd)

    -- For debugging
    frame_valid : out std_logic; -- high when frame_bit_out is valid on bit_tick
    frame_start : out std_logic; -- high on first header bit
    frame_end : out std_logic; -- high on last bit
    busy : out std_logic -- high when mid-frame
    --header_dbg : out std_logic_vector(47 downto 0)
  );
end entity tm_framer;

architecture rtl of tm_framer is
  constant header_bytes : integer := 6;
  constant crc_bytes : integer := 2;
  constant payload_bits : integer := G_PAYLOAD_BYTES * 8;
  constant crc_init : std_logic_vector(15 downto 0) := (others => '1');
  constant asm_32 : std_logic_vector(31 downto 0) := x"1ACFFC1D";
    
  type tmframe_fsm is (IDLE, SEND_ASM, SEND_HEADER, SEND_PAYLOAD, SEND_CRC);
    signal state : tmframe_fsm := IDLE;
    signal header_reg : std_logic_vector(47 downto 0);
    signal master_frame_count : unsigned(7 downto 0) := (others => '0');
    signal virtual_frame_count : unsigned(7 downto 0) := (others => '0');
    signal frame_status : std_logic_vector(15 downto 0) := "0001100000000000";
    signal asm_idx : integer range 0 to 31 := 31;
    signal hdr_idx : integer range 0 to 47 := 47;
    signal pay_idx : integer range 0 to payload_bits - 1 := 0;
    signal crc_reg : std_logic_vector(15 downto 0) := crc_init;
    signal crc_shift : std_logic_vector(15 downto 0);
    signal crc_idx : integer range 0 to 15 := 15;

    begin
      process(clk)
      variable din : std_logic;
      variable fb : std_logic;
      variable crc_next : std_logic_vector(15 downto 0);
      begin
       assert (G_PAYLOAD_BYTES > 0) report "Payload must be > 0 bytes" severity failure;
       assert (payload_bits > 0) report "Payload bits must be > 0" severity failure;
       if rising_edge(clk) then
          if rst_n = '0' then 
             master_frame_count <= (others => '0');
             virtual_frame_count <= (others => '0');
             state <= IDLE; 
             hdr_idx <= 47; 
             -- header_dbg <= (others => '0');
             pay_idx <= 0; 
             crc_idx <= 15;
             crc_reg <=  crc_init; 
             frame_bit_out <= '0'; 
             payload_advance <= '0'; 
             frame_valid <= '0'; 
             frame_start <= '0'; 
             frame_end <= '0'; 
             busy <= '0';
             asm_idx <= 31;
          else                    
             frame_valid <= '0'; 
             frame_start <= '0';
             frame_end <= '0';
             payload_advance <= '0';
             --frame_bit_out <= '0';
             if state = IDLE then
               busy <= '0';
             else
               busy <= '1';
             end if;
             if bit_tick = '1' and downstream_ready = '1' then 
               case state is
                 when IDLE =>
                    if enable = '1' then 
                       hdr_idx <= 47;
                       crc_idx <= 15;
                       header_reg <= "00" & std_logic_vector(to_unsigned(G_SCID, 10)) & std_logic_vector(to_unsigned(G_VCID, 3)) & '0' & std_logic_vector(master_frame_count) & std_logic_vector(virtual_frame_count) & frame_status; -- Header design given in Section 6.1.3.2 of the Final Report
                       crc_reg <= crc_init; 
                       crc_shift <= (others => '0');
                       state <= SEND_ASM;
                    end if;
                 when SEND_ASM =>                          -- ASM must preceed the frame
                    frame_bit_out <= asm_32(asm_idx);
                    frame_valid   <= '1';
                    if asm_idx = 0 then
                      asm_idx <= 31;
                      hdr_idx <= 47;
                      state   <= SEND_HEADER;
                    else
                      asm_idx <= asm_idx - 1;
                      state   <= SEND_ASM; 
                    end if;
                 when SEND_HEADER => 
                   frame_valid <= '1';
                   if hdr_idx = 47 then 
                     frame_start <= '1';
                   end if;
                   frame_bit_out <= header_reg(hdr_idx); 
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
                   if fb='1' then 
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
                        crc_idx    <= 15;
                        frame_end  <= '1';
                        -- increment counters
                        master_frame_count  <= master_frame_count + 1;
                        virtual_frame_count <= virtual_frame_count + 1;
                        -- prepare next frame immediately
                        asm_idx <= 31;
                        hdr_idx <= 47;
                        header_reg <= "00" &
                                      std_logic_vector(to_unsigned(G_SCID, 10)) &
                                      std_logic_vector(to_unsigned(G_VCID, 3)) & '0' &
                                      std_logic_vector(master_frame_count + 1) &
                                      std_logic_vector(virtual_frame_count + 1) &
                                      frame_status;
                        crc_reg   <= crc_init;
                        crc_shift <= (others => '0');
                        if enable = '1' then
                          state <= SEND_ASM;
                        else
                          state <= IDLE;
                        end if;
                    else
                      crc_idx <= crc_idx - 1;
                    end if;
                  end case;
               end if;
             end if;          
          end if;        
      end process;
end architecture;
