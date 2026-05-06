library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity acc_image_filter_axi4lite_wrapper is
    Generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 9
    );
    Port ( reset : in STD_LOGIC;
           clk : in STD_LOGIC;
           		
           -------- AXI4-Lite interface -------
	       --  AXI4-Lite Write address channel
		   s_axi_lite_awaddr  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		   -- protection type (priviledge and security of transaction)
		   s_axi_lite_awprot  : in std_logic_vector(2 downto 0);
		   s_axi_lite_awvalid : in std_logic;
		   s_axi_lite_awready : out std_logic;
		
		   --  AXI4-Lite Write data channel
		   s_axi_lite_wdata  : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		   s_axi_lite_wstrb  : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		   s_axi_lite_wvalid : in std_logic;
		   s_axi_lite_wready : out std_logic;
		
		   --  AXI4-Lite Write response channel
		   s_axi_lite_bresp  : out std_logic_vector(1 downto 0);
		   s_axi_lite_bvalid : out std_logic;
		   s_axi_lite_bready : in std_logic;
		
		   --  AXI4-Lite Read address related signals
		   s_axi_lite_araddr  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		   -- protection type (priviledge and security of transaction)
		   s_axi_lite_arprot  : in std_logic_vector(2 downto 0);
		   s_axi_lite_arvalid : in std_logic;
		   s_axi_lite_arready : out std_logic;
		
		   --  AXI4-Lite Read data related signals
		   s_axi_lite_rdata  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		   s_axi_lite_rvalid : out std_logic;
		   s_axi_lite_rready : in std_logic;
		   s_axi_lite_rresp  : out std_logic_vector(1 downto 0);

           --axi stream portovi
           s_axis_data_in_tdata : in STD_LOGIC_VECTOR (7 downto 0);
           s_axis_data_in_tvalid : in STD_LOGIC;
           s_axis_data_in_tready : out STD_LOGIC;
           s_axis_data_in_tlast : in STD_LOGIC;
           
           m_axis_data_out_tdata : out STD_LOGIC_VECTOR (15 downto 0);
           m_axis_data_out_tvalid : out STD_LOGIC;
           m_axis_data_out_tready : in STD_LOGIC;
           m_axis_data_out_tlast : out STD_LOGIC
           );
end acc_image_filter_axi4lite_wrapper;

architecture Behavioral of acc_image_filter_axi4lite_wrapper is
    
    --konfiguracioni registri modula akceleratora
    signal reg_ctrl : std_logic_vector(15 downto 0);
    signal reg_radius : std_logic_vector(15 downto 0);
    signal reg_img_w : std_logic_vector(15 downto 0);
    signal reg_img_h : std_logic_vector(15 downto 0);
    signal reg_coeff_scale : std_logic_vector(15 downto 0);
    
    type reg_array_type is array (0 to 80) of std_logic_vector(15 downto 0); --velicina pogodna za sve maske
    signal reg_coeff : reg_array_type;
   
    
    -- AXI4-Lite register addresses  
    constant REG_CTRL_ADDR        : std_logic_vector(6 downto 0) := "0000000";
    constant REG_RADIUS_ADDR      : std_logic_vector(6 downto 0) := "0000001";
    constant REG_IMG_W_ADDR       : std_logic_vector(6 downto 0) := "0000010";
    constant REG_IMG_H_ADDR       : std_logic_vector(6 downto 0) := "0000011";
    constant REG_COEFF_SCALE_ADDR : std_logic_vector(6 downto 0) := "0000100";
    constant REG_COEFF_START_ADDR : std_logic_vector(6 downto 0) := "0000101";
    
    -- When addressing 32-bit registers, 2 LSB of address are not used
    -- since each register occupies 4 byte addresses.
    constant ADDR_LSB   : natural := (C_S_AXI_DATA_WIDTH/32) + 1;
    
    -- AXI4-Lite internal signals
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    
    signal axi_bvalid  : std_logic;
    
    signal axi_arready : std_logic;
    signal axi_rvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

    signal reg_waddr : std_logic_vector(C_S_AXI_ADDR_WIDTH-ADDR_LSB-1 downto 0);
    signal reg_raddr : std_logic_vector(C_S_AXI_ADDR_WIDTH-ADDR_LSB-1 downto 0);
    
    signal axi_write_ready : std_logic;
    signal axi_read_ready : std_logic;
    
    -- AXI4-Lite state machines
    type fsm_read_state_type is  (ReadAddress,  ReadData);
    type fsm_write_state_type is (WriteAddress, WriteData, WriteStalled);
    
    signal fsm_axi_read_state : fsm_read_state_type;
    signal fsm_axi_write_state : fsm_write_state_type;
   
begin
    -- AXI4-Lite write registers
    process (clk) is
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                reg_ctrl        <= (others => '0');
                reg_radius      <= (others => '0');
                reg_img_w       <= (others => '0');
                reg_img_h       <= (others => '0');
                reg_coeff_scale <= (others => '0');
                for i in 0 to 80 loop
                    reg_coeff(i) <= (others => '0');
                end loop;
            else
                if (axi_write_ready = '1') then
                    if (s_axi_lite_wstrb(1 downto 0) = "11") then
                        case (reg_waddr) is
                            when REG_CTRL_ADDR => reg_ctrl <= s_axi_lite_wdata(15 downto 0);
                            when REG_RADIUS_ADDR => reg_radius <= s_axi_lite_wdata(15 downto 0);
                            when REG_IMG_W_ADDR => reg_img_w <= s_axi_lite_wdata(15 downto 0);
                            when REG_IMG_H_ADDR => reg_img_h <= s_axi_lite_wdata(15 downto 0);
                            when REG_COEFF_SCALE_ADDR => reg_coeff_scale <= s_axi_lite_wdata(15 downto 0);
                            when others => 
                                if (unsigned(reg_waddr) >= unsigned(REG_COEFF_START_ADDR) and 
                                    unsigned(reg_waddr) <  unsigned(REG_COEFF_START_ADDR) + 81) then
                                  
                                    reg_coeff(to_integer(unsigned(reg_waddr) - unsigned(REG_COEFF_START_ADDR))) <= s_axi_lite_wdata(15 downto 0);
                                end if;    
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- AXI4-Lite read registers
    process(reg_raddr, reg_ctrl, reg_radius, reg_img_w, reg_img_h, reg_coeff_scale, reg_coeff)
    variable idx : integer;
    begin
        s_axi_lite_rdata <= (others => '0');
        idx := to_integer(unsigned(reg_raddr) - unsigned(REG_COEFF_START_ADDR));
    
        case reg_raddr is
            when REG_CTRL_ADDR => s_axi_lite_rdata(15 downto 0) <= reg_ctrl;
            when REG_RADIUS_ADDR => s_axi_lite_rdata(15 downto 0) <= reg_radius;
            when REG_IMG_W_ADDR => s_axi_lite_rdata(15 downto 0) <= reg_img_w;
            when REG_IMG_H_ADDR => s_axi_lite_rdata(15 downto 0) <= reg_img_h;
            when REG_COEFF_SCALE_ADDR => s_axi_lite_rdata(15 downto 0) <= reg_coeff_scale;
            when others =>
                if (idx >= 0 and idx < 81) then
                    s_axi_lite_rdata(15 downto 0) <= reg_coeff(idx);
                end if;
        end case;
    end process;                         
    
    -- Set default value of read and write response to OKAY
    s_axi_lite_bresp <= "00";
    s_axi_lite_rresp <= "00";

    -- AXI4-Lite read state machine
    process (clk) is
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                axi_arready <= '0';
                axi_rvalid  <= '0';
                fsm_axi_read_state <= ReadAddress;
            else
                case (fsm_axi_read_state) is
                    when ReadAddress =>
                        axi_arready <= '1';
                        if (axi_arready = '1' and s_axi_lite_arvalid = '1') then
                            axi_araddr <= s_axi_lite_araddr;
                            axi_arready <= '0';
                            axi_rvalid <= '1';
                            fsm_axi_read_state <= ReadData;
                        end if;
                    when ReadData =>
                        
                        if (s_axi_lite_rready = '1' and axi_rvalid = '1') then
                            axi_rvalid <= '0';
                            axi_arready <= '1';
                            fsm_axi_read_state <= ReadAddress;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    s_axi_lite_arready <= axi_arready;
    s_axi_lite_rvalid <= axi_rvalid;
    
    reg_raddr <= s_axi_lite_araddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB) when (s_axi_lite_arvalid = '1') else
                        axi_araddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB);
    
    -- AXI4-Lite write state machine
    process (clk) is
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
                fsm_axi_write_state <= WriteAddress;
            else
                case (fsm_axi_write_state) is                                              
                    when WriteAddress =>
                        axi_awready <= '1';
                        axi_wready <= '1';
                    
                        if (axi_awready = '1' and s_axi_lite_awvalid = '1') then
                            axi_awaddr <= s_axi_lite_awaddr;
                            if (axi_wready = '1' and s_axi_lite_wvalid = '1') then
                                axi_bvalid <= '1';
                                if (s_axi_lite_bready = '0') then
                                    axi_awready <= '0';
                                    axi_wready <= '0';
                                    fsm_axi_write_state <= WriteStalled;
                                end if;
                            else
                                axi_awready <= '0';
                                fsm_axi_write_state <= WriteData;
                                if (s_axi_lite_bready = '1' and axi_bvalid = '1') then
                                    axi_bvalid <= '0';
                                end if;
                            end if;
                        else
                            if (s_axi_lite_bready = '1' and axi_bvalid = '1') then
                                axi_bvalid <= '0';
                            end if;
                        end if;
                        
                    when WriteData =>
                        if (axi_wready = '1' and s_axi_lite_wvalid = '1') then
                            axi_bvalid <= '1';
                            if (s_axi_lite_bready = '0') then
                                axi_awready <= '0';
                                axi_wready <= '0';
                                fsm_axi_write_state <= WriteStalled;
                            else
                                axi_awready <= '1';
                                axi_wready <= '1';
                                fsm_axi_write_state <= WriteAddress;
                            end if;
                        else
                            if (s_axi_lite_bready = '1' and axi_bvalid = '1') then
                                axi_bvalid <= '0';
                            end if;
                        end if;
                        
                    when WriteStalled =>
                        if (s_axi_lite_bready = '1' and axi_bvalid = '1') then
                            axi_bvalid <= '0';
                            axi_awready <= '1';
                            axi_wready <= '1';
                            fsm_axi_write_state <= WriteAddress;
                        end if;
                        
                    when others =>
                        axi_awready <= '0';
                        axi_wready <= '0';
                        axi_bvalid <= '0';
                        fsm_axi_write_state <= WriteAddress;
                end case;
            end if;
        end if;
     end process;
        
    s_axi_lite_awready <= axi_awready;
    s_axi_lite_wready  <= axi_wready;
    s_axi_lite_bvalid <= axi_bvalid;
    
    axi_write_ready <= '1' when ((fsm_axi_write_state = WriteAddress and s_axi_lite_awvalid = '1' and s_axi_lite_wvalid = '1') or
                                 (fsm_axi_write_state = WriteData and s_axi_lite_wvalid = '1')) else '0';
    
    reg_waddr <= s_axi_lite_awaddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB) when (s_axi_lite_awvalid = '1') else axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB);--s_axi_lite_awaddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB) when (s_axi_lite_awvalid = '1') else axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB);   

 
    --istanciranje komponente filtra
    image_filter_inst : entity work.acc_image_filter
    generic map (
        C_MAX_IMG_WIDTH => 1920
    )
    port map (
        clk                   => clk,
        reset                 => reset,
        s_axis_data_in_tdata  => s_axis_data_in_tdata,
        s_axis_data_in_tvalid => s_axis_data_in_tvalid,
        s_axis_data_in_tready => s_axis_data_in_tready,
        s_axis_data_in_tlast  => s_axis_data_in_tlast,
        m_axis_data_out_tdata => m_axis_data_out_tdata,
        m_axis_data_out_tvalid=> m_axis_data_out_tvalid,
        m_axis_data_out_tready=> m_axis_data_out_tready,
        m_axis_data_out_tlast => m_axis_data_out_tlast,
        p_reg_ctrl            => reg_ctrl,
        p_reg_radius          => reg_radius,
        p_reg_img_w           => reg_img_w,
        p_reg_img_h           => reg_img_h,
        p_reg_coeff_scale     => reg_coeff_scale,
        -- Mapiranje svih 81 koeficijenata
        p_reg_coeff0  => reg_coeff(0),  p_reg_coeff1  => reg_coeff(1),  p_reg_coeff2  => reg_coeff(2),
        p_reg_coeff3  => reg_coeff(3),  p_reg_coeff4  => reg_coeff(4),  p_reg_coeff5  => reg_coeff(5),
        p_reg_coeff6  => reg_coeff(6),  p_reg_coeff7  => reg_coeff(7),  p_reg_coeff8  => reg_coeff(8),
        p_reg_coeff9  => reg_coeff(9),  p_reg_coeff10 => reg_coeff(10), p_reg_coeff11 => reg_coeff(11),
        p_reg_coeff12 => reg_coeff(12), p_reg_coeff13 => reg_coeff(13), p_reg_coeff14 => reg_coeff(14),
        p_reg_coeff15 => reg_coeff(15), p_reg_coeff16 => reg_coeff(16), p_reg_coeff17 => reg_coeff(17),
        p_reg_coeff18 => reg_coeff(18), p_reg_coeff19 => reg_coeff(19), p_reg_coeff20 => reg_coeff(20),
        p_reg_coeff21 => reg_coeff(21), p_reg_coeff22 => reg_coeff(22), p_reg_coeff23 => reg_coeff(23),
        p_reg_coeff24 => reg_coeff(24), p_reg_coeff25 => reg_coeff(25), p_reg_coeff26 => reg_coeff(26),
        p_reg_coeff27 => reg_coeff(27), p_reg_coeff28 => reg_coeff(28), p_reg_coeff29 => reg_coeff(29),
        p_reg_coeff30 => reg_coeff(30), p_reg_coeff31 => reg_coeff(31), p_reg_coeff32 => reg_coeff(32),
        p_reg_coeff33 => reg_coeff(33), p_reg_coeff34 => reg_coeff(34), p_reg_coeff35 => reg_coeff(35),
        p_reg_coeff36 => reg_coeff(36), p_reg_coeff37 => reg_coeff(37), p_reg_coeff38 => reg_coeff(38),
        p_reg_coeff39 => reg_coeff(39), p_reg_coeff40 => reg_coeff(40), p_reg_coeff41 => reg_coeff(41),
        p_reg_coeff42 => reg_coeff(42), p_reg_coeff43 => reg_coeff(43), p_reg_coeff44 => reg_coeff(44),
        p_reg_coeff45 => reg_coeff(45), p_reg_coeff46 => reg_coeff(46), p_reg_coeff47 => reg_coeff(47),
        p_reg_coeff48 => reg_coeff(48), p_reg_coeff49 => reg_coeff(49), p_reg_coeff50 => reg_coeff(50),
        p_reg_coeff51 => reg_coeff(51), p_reg_coeff52 => reg_coeff(52), p_reg_coeff53 => reg_coeff(53),
        p_reg_coeff54 => reg_coeff(54), p_reg_coeff55 => reg_coeff(55), p_reg_coeff56 => reg_coeff(56),
        p_reg_coeff57 => reg_coeff(57), p_reg_coeff58 => reg_coeff(58), p_reg_coeff59 => reg_coeff(59),
        p_reg_coeff60 => reg_coeff(60), p_reg_coeff61 => reg_coeff(61), p_reg_coeff62 => reg_coeff(62),
        p_reg_coeff63 => reg_coeff(63), p_reg_coeff64 => reg_coeff(64), p_reg_coeff65 => reg_coeff(65),
        p_reg_coeff66 => reg_coeff(66), p_reg_coeff67 => reg_coeff(67), p_reg_coeff68 => reg_coeff(68),
        p_reg_coeff69 => reg_coeff(69), p_reg_coeff70 => reg_coeff(70), p_reg_coeff71 => reg_coeff(71),
        p_reg_coeff72 => reg_coeff(72), p_reg_coeff73 => reg_coeff(73), p_reg_coeff74 => reg_coeff(74),
        p_reg_coeff75 => reg_coeff(75), p_reg_coeff76 => reg_coeff(76), p_reg_coeff77 => reg_coeff(77),
        p_reg_coeff78 => reg_coeff(78), p_reg_coeff79 => reg_coeff(79), p_reg_coeff80 => reg_coeff(80)
    );

end Behavioral;
