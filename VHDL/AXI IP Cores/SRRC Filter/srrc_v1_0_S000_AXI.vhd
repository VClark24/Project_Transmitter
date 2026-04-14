library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity srrc_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        -- User DSP ports
        sample_en_i      : in  std_logic;
        symbol_en_i      : in  std_logic;
        half_symbol_en_i : in  std_logic;

        i_symbol_i       : in  signed(15 downto 0);
        q_symbol_i       : in  signed(15 downto 0);

        i_out_o          : out signed(15 downto 0);
        q_out_o          : out signed(15 downto 0);

        -- AXI4-Lite interface
        S_AXI_ACLK       : in  std_logic;
        S_AXI_ARESETN    : in  std_logic;

        S_AXI_AWADDR     : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT     : in  std_logic_vector(2 downto 0);
        S_AXI_AWVALID    : in  std_logic;
        S_AXI_AWREADY    : out std_logic;

        S_AXI_WDATA      : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB      : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID     : in  std_logic;
        S_AXI_WREADY     : out std_logic;

        S_AXI_BRESP      : out std_logic_vector(1 downto 0);
        S_AXI_BVALID     : out std_logic;
        S_AXI_BREADY     : in  std_logic;

        S_AXI_ARADDR     : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT     : in  std_logic_vector(2 downto 0);
        S_AXI_ARVALID    : in  std_logic;
        S_AXI_ARREADY    : out std_logic;

        S_AXI_RDATA      : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP      : out std_logic_vector(1 downto 0);
        S_AXI_RVALID     : out std_logic;
        S_AXI_RREADY     : in  std_logic
    );
end srrc_v1_0_S00_AXI;

architecture arch_imp of srrc_v1_0_S00_AXI is

    -- AXI signals
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

    constant ADDR_LSB           : integer := (C_S_AXI_DATA_WIDTH/32) + 1;
    constant OPT_MEM_ADDR_BITS  : integer := 1;

    signal slv_reg0             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg1             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg2             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg3             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    signal slv_reg_rden         : std_logic;
    signal slv_reg_wren         : std_logic;
    signal reg_data_out         : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal aw_en                : std_logic;

    -- SRRC control/status
    signal srrc_enable          : std_logic;
    signal i_filt_s             : signed(15 downto 0);
    signal q_filt_s             : signed(15 downto 0);

    signal status_word          : std_logic_vector(31 downto 0);
    
    signal reset_internal : std_logic;

begin

    -- AXI outputs
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    -- Control register bit 0 = SRRC enable
    srrc_enable <= slv_reg0(0);
    
    -- Reset Intermediary
    reset_internal <= not S_AXI_ARESETN;

    -- Status register
    -- bit0 = SRRC enable
    status_word <= (31 downto 1 => '0') & srrc_enable;

    ------------------------------------------------------------------------------
    -- AXI write address ready
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- Latch AWADDR
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- AXI write data ready
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- Write enable
    ------------------------------------------------------------------------------
    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

    ------------------------------------------------------------------------------
    -- Register write logic
    ------------------------------------------------------------------------------
    process(S_AXI_ACLK)
        variable loc_addr   : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
        variable byte_index : integer;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
                slv_reg2 <= (others => '0');
                slv_reg3 <= (others => '0');
            else
                if slv_reg_wren = '1' then
                    loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
                    case loc_addr is
                        when b"00" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if S_AXI_WSTRB(byte_index) = '1' then
                                    slv_reg0(byte_index*8+7 downto byte_index*8) <=
                                        S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"01" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if S_AXI_WSTRB(byte_index) = '1' then
                                    slv_reg1(byte_index*8+7 downto byte_index*8) <=
                                        S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"10" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if S_AXI_WSTRB(byte_index) = '1' then
                                    slv_reg2(byte_index*8+7 downto byte_index*8) <=
                                        S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"11" =>
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if S_AXI_WSTRB(byte_index) = '1' then
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

    ------------------------------------------------------------------------------
    -- Write response
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- Read address ready + latch
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- Read valid/resp
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- Read mux
    ------------------------------------------------------------------------------
    process(slv_reg0, slv_reg1, slv_reg2, slv_reg3, axi_araddr, status_word)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        case loc_addr is
            when b"00" => reg_data_out <= slv_reg0;
            when b"01" => reg_data_out <= status_word;
            when b"10" => reg_data_out <= slv_reg2;
            when b"11" => reg_data_out <= slv_reg3;
            when others => reg_data_out <= (others => '0');
        end case;
    end process;

    ------------------------------------------------------------------------------
    -- Register the read data
    ------------------------------------------------------------------------------
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

    ------------------------------------------------------------------------------
    -- SRRC core
    ------------------------------------------------------------------------------
    u_srrc_filter : entity work.srrc_filter
        port map (
            clk              => S_AXI_ACLK,
            rst              => reset_internal,
            sample_en_i      => sample_en_i,
            symbol_en_i      => symbol_en_i,
            half_symbol_en_i => half_symbol_en_i,
            i_symbol_i       => i_symbol_i,
            q_symbol_i       => q_symbol_i,
            i_out_o          => i_filt_s,
            q_out_o          => q_filt_s
        );

    ------------------------------------------------------------------------------
    -- Enable / bypass
    ------------------------------------------------------------------------------
    i_out_o <= i_filt_s when srrc_enable = '1' else i_symbol_i;
    q_out_o <= q_filt_s when srrc_enable = '1' else q_symbol_i;

end arch_imp;
