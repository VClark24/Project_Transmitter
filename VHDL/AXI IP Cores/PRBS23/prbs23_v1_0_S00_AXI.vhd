-----------------------------------------------------------------------------------------------
-- This axi slave wrapper creates and defines the following registers
-- 0x40001000 - Read/Write. Control register (enable and rests block)
-- 0x40001004 - Read Only. Allows user to view current output bit of the PRBS block
-- 0x40001008 - Read Only. Serves as the internal state register. User can view current LFSR
-- 0x4000100C - Read/Write. Unused
----------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prbs_23_v1_0_S00_AXI is
  generic (
    C_S_AXI_DATA_WIDTH : integer := 32;
    C_S_AXI_ADDR_WIDTH : integer := 4
  );
  port (
    -- User output to feed next IP
    prbs_bit_o    : out std_logic;
    
    -- Input
    prbs_step_i : in std_logic;

    -- AXI4-Lite signals
    S_AXI_ACLK    : in  std_logic;
    S_AXI_ARESETN : in  std_logic;

    S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in  std_logic;
    S_AXI_AWREADY : out std_logic;

    S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    S_AXI_WVALID  : in  std_logic;
    S_AXI_WREADY  : out std_logic;

    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in  std_logic;

    S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in  std_logic;
    S_AXI_ARREADY : out std_logic;

    S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in  std_logic
  );
end prbs_23_v1_0_S00_AXI;

architecture arch_imp of prbs_23_v1_0_S00_AXI is

  -- AXI4LITE internal signals
  signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_awready : std_logic;
  signal axi_wready  : std_logic;
  signal axi_bresp   : std_logic_vector(1 downto 0);
  signal axi_bvalid  : std_logic;
  signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_arready : std_logic;
  signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal axi_rresp   : std_logic_vector(1 downto 0);
  signal axi_rvalid  : std_logic;

  constant ADDR_LSB : integer := (C_S_AXI_DATA_WIDTH/32) + 1;
  constant OPT_MEM_ADDR_BITS : integer := 1;

  -- 4 slave regs
  signal slv_reg0 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal slv_reg1 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal slv_reg2 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal slv_reg3 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

  signal slv_reg_rden : std_logic;
  signal slv_reg_wren : std_logic;
  signal reg_data_out : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal aw_en        : std_logic;

  -- PRBS signals
  signal prbs_en        : std_logic;
  signal prbs_out_bit   : std_logic;
  signal prbs_state     : std_logic_vector(22 downto 0);
  signal sw_reset_pulse : std_logic := '0';
  signal prbs_reset : std_logic := '0';
  
  -- Status Signal
  signal status_word : std_logic_vector(31 downto 0);
  signal state_word : std_logic_vector(31 downto 0);
  
  -- Enable Gating
  signal prbs_enable_gate : std_logic;
  
begin

  -- Output connect
  S_AXI_AWREADY <= axi_awready;
  S_AXI_WREADY  <= axi_wready;
  S_AXI_BRESP   <= axi_bresp;
  S_AXI_BVALID  <= axi_bvalid;
  S_AXI_ARREADY <= axi_arready;
  S_AXI_RDATA   <= axi_rdata;
  S_AXI_RRESP   <= axi_rresp;
  S_AXI_RVALID  <= axi_rvalid;

  -- PRBS enable from CTRL bit0
  prbs_en <= slv_reg0(0);

  -- PRBS bit out to top-level
  prbs_bit_o <= prbs_out_bit;
  
  -- PRBS reset
  prbs_reset <= (not S_AXI_ARESETN) or sw_reset_pulse;
  
  -- Status Assignment
  status_word <= (31 downto 1 => '0') & prbs_out_bit;
  state_word <= (31 downto 23 => '0') & prbs_state;
 
  -- Enable Gating
  prbs_enable_gate <= prbs_step_i and prbs_en;

  --------------------------------------------------------------------------
  -- AXI write address ready
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awready <= '0';
        aw_en <= '1';
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awready <= '1';
          aw_en <= '0';
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          aw_en <= '1';
          axi_awready <= '0';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Latch AWADDR
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awaddr <= (others => '0');
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awaddr <= S_AXI_AWADDR;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- AXI write data ready
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_wready <= '0';
      else
        if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
          axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Write enable
  --------------------------------------------------------------------------
  slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

  --------------------------------------------------------------------------
  -- Register write logic (reg1/reg2 read-only)
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
    variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    variable byte_index : integer;
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        slv_reg0 <= (others => '0');
        slv_reg1 <= (others => '0');
        slv_reg2 <= (others => '0');
        slv_reg3 <= (others => '0');
      else
        loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

        if (slv_reg_wren = '1') then
          case loc_addr is
            when b"00" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg0(byte_index*8+7 downto byte_index*8) <=
                    S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;

            when b"01" =>
              null; -- read-only status

            when b"10" =>
              null; -- read-only state

            when b"11" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg3(byte_index*8+7 downto byte_index*8) <=
                    S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;

            when others =>
              null;
          end case;
        end if;

      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Software reset pulse: write 1 to CTRL bit1 (reg0)
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
    variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        sw_reset_pulse <= '0';
      else
        sw_reset_pulse <= '0';

        if slv_reg_wren = '1' then
          loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
          if (loc_addr = b"00") then
            if (S_AXI_WSTRB(0) = '1') and (S_AXI_WDATA(1) = '1') then
              sw_reset_pulse <= '1';
            end if;
          end if;
        end if;

      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Write response
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_bvalid <= '0';
        axi_bresp  <= "00";
      else
        if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0') then
          axi_bvalid <= '1';
          axi_bresp  <= "00";
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Read address ready + latch
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr  <= (others => '0');
      else
        if (axi_arready = '0' and S_AXI_ARVALID = '1') then
          axi_arready <= '1';
          axi_araddr  <= S_AXI_ARADDR;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Read valid/resp
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= "00";
      else
        if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
          axi_rvalid <= '1';
          axi_rresp  <= "00";
        elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

  --------------------------------------------------------------------------
  -- Read mux
  --------------------------------------------------------------------------
  process(slv_reg0, slv_reg1, slv_reg2, slv_reg3, axi_araddr)
    variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
    case loc_addr is
      when b"00" => reg_data_out <= slv_reg0;
      when b"01" => reg_data_out <= status_word;
      when b"10" => reg_data_out <= state_word;
      when b"11" => reg_data_out <= slv_reg3;
      when others => reg_data_out <= (others => '0');
    end case;
  end process;

  --------------------------------------------------------------------------
  -- Register the read data
  --------------------------------------------------------------------------
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rdata <= (others => '0');
      else
        if slv_reg_rden = '1' then
          axi_rdata <= reg_data_out;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- PRBS core instantiation (existing prbs23 entity)
  --------------------------------------------------------------------------
  u_prbs23 : entity work.prbs23
    port map (
      clk         => S_AXI_ACLK,
      reset       => prbs_reset,
      enable      => prbs_enable_gate,
      prbs_output => prbs_out_bit,
      state_dbg   => prbs_state
    );

end arch_imp;
