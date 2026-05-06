library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_acc_image_filter is
end tb_acc_image_filter;

architecture Behavioral of tb_acc_image_filter is

    constant CLK_PERIOD : time := 10 ns;
    constant IMG_W : integer := 128; 
    constant IMG_H : integer := 128;
    constant TOTAL_PIXELS : integer := IMG_W * IMG_H;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';

    -- AXI-Stream ulaz
    signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;
    signal s_axis_tlast  : std_logic := '0';

    -- AXI-Stream izlaz
    signal m_axis_tdata  : std_logic_vector(15 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1'; 
    signal m_axis_tlast  : std_logic;

    -- Signali za kontrolu progresa u TB
    signal current_pixel_count : integer := 0;

    -- Konfiguracija
    signal p_reg_ctrl          : std_logic_vector(15 downto 0) := x"0000";
    signal p_reg_radius        : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(0, 16));
    signal p_reg_img_w         : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(IMG_W, 16));
    signal p_reg_img_h         : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(IMG_H, 16));
    signal p_reg_coeff_scale   : std_logic_vector(15 downto 0) := "0001000000000000";

    -- Koeficijenti: Koristimo niz radi lakšeg upravljanja u TB
    type coeff_array is array (0 to 80) of std_logic_vector(15 downto 0);
    --signal p_reg_coeff : coeff_array := (others => "0000111000111001");
    signal p_reg_coeff : coeff_array := (
        0 to 80 => "0000111000111001",  
        others  => (others => '0')
    );

begin

    uut: entity work.acc_image_filter
        generic map ( C_MAX_IMG_WIDTH => 1920 )
        port map (
            clk => clk, 
            reset => reset,
            s_axis_data_in_tdata  => s_axis_tdata, 
            s_axis_data_in_tvalid => s_axis_tvalid,
            s_axis_data_in_tready => s_axis_tready, 
            s_axis_data_in_tlast  => s_axis_tlast,
            m_axis_data_out_tdata => m_axis_tdata, 
            m_axis_data_out_tvalid=> m_axis_tvalid,
            m_axis_data_out_tready=> m_axis_tready, 
            m_axis_data_out_tlast => m_axis_tlast,
            
            p_reg_ctrl        => p_reg_ctrl, 
            p_reg_radius      => p_reg_radius,
            p_reg_img_w       => p_reg_img_w, 
            p_reg_img_h       => p_reg_img_h,
            p_reg_coeff_scale => p_reg_coeff_scale,
            
            -- Mapiranje svih 81 koeficijenata na portove UUT-a
            p_reg_coeff0  => p_reg_coeff(0),  p_reg_coeff1  => p_reg_coeff(1),  p_reg_coeff2  => p_reg_coeff(2),
            p_reg_coeff3  => p_reg_coeff(3),  p_reg_coeff4  => p_reg_coeff(4),  p_reg_coeff5  => p_reg_coeff(5),
            p_reg_coeff6  => p_reg_coeff(6),  p_reg_coeff7  => p_reg_coeff(7),  p_reg_coeff8  => p_reg_coeff(8),
            p_reg_coeff9  => p_reg_coeff(9),  p_reg_coeff10 => p_reg_coeff(10), p_reg_coeff11 => p_reg_coeff(11),
            p_reg_coeff12 => p_reg_coeff(12), p_reg_coeff13 => p_reg_coeff(13), p_reg_coeff14 => p_reg_coeff(14),
            p_reg_coeff15 => p_reg_coeff(15), p_reg_coeff16 => p_reg_coeff(16), p_reg_coeff17 => p_reg_coeff(17),
            p_reg_coeff18 => p_reg_coeff(18), p_reg_coeff19 => p_reg_coeff(19), p_reg_coeff20 => p_reg_coeff(20),
            p_reg_coeff21 => p_reg_coeff(21), p_reg_coeff22 => p_reg_coeff(22), p_reg_coeff23 => p_reg_coeff(23),
            p_reg_coeff24 => p_reg_coeff(24), p_reg_coeff25 => p_reg_coeff(25), p_reg_coeff26 => p_reg_coeff(26),
            p_reg_coeff27 => p_reg_coeff(27), p_reg_coeff28 => p_reg_coeff(28), p_reg_coeff29 => p_reg_coeff(29),
            p_reg_coeff30 => p_reg_coeff(30), p_reg_coeff31 => p_reg_coeff(31), p_reg_coeff32 => p_reg_coeff(32),
            p_reg_coeff33 => p_reg_coeff(33), p_reg_coeff34 => p_reg_coeff(34), p_reg_coeff35 => p_reg_coeff(35),
            p_reg_coeff36 => p_reg_coeff(36), p_reg_coeff37 => p_reg_coeff(37), p_reg_coeff38 => p_reg_coeff(38),
            p_reg_coeff39 => p_reg_coeff(39), p_reg_coeff40 => p_reg_coeff(40), p_reg_coeff41 => p_reg_coeff(41),
            p_reg_coeff42 => p_reg_coeff(42), p_reg_coeff43 => p_reg_coeff(43), p_reg_coeff44 => p_reg_coeff(44),
            p_reg_coeff45 => p_reg_coeff(45), p_reg_coeff46 => p_reg_coeff(46), p_reg_coeff47 => p_reg_coeff(47),
            p_reg_coeff48 => p_reg_coeff(48), p_reg_coeff49 => p_reg_coeff(49), p_reg_coeff50 => p_reg_coeff(50),
            p_reg_coeff51 => p_reg_coeff(51), p_reg_coeff52 => p_reg_coeff(52), p_reg_coeff53 => p_reg_coeff(53),
            p_reg_coeff54 => p_reg_coeff(54), p_reg_coeff55 => p_reg_coeff(55), p_reg_coeff56 => p_reg_coeff(56),
            p_reg_coeff57 => p_reg_coeff(57), p_reg_coeff58 => p_reg_coeff(58), p_reg_coeff59 => p_reg_coeff(59),
            p_reg_coeff60 => p_reg_coeff(60), p_reg_coeff61 => p_reg_coeff(61), p_reg_coeff62 => p_reg_coeff(62),
            p_reg_coeff63 => p_reg_coeff(63), p_reg_coeff64 => p_reg_coeff(64), p_reg_coeff65 => p_reg_coeff(65),
            p_reg_coeff66 => p_reg_coeff(66), p_reg_coeff67 => p_reg_coeff(67), p_reg_coeff68 => p_reg_coeff(68),
            p_reg_coeff69 => p_reg_coeff(69), p_reg_coeff70 => p_reg_coeff(70), p_reg_coeff71 => p_reg_coeff(71),
            p_reg_coeff72 => p_reg_coeff(72), p_reg_coeff73 => p_reg_coeff(73), p_reg_coeff74 => p_reg_coeff(74),
            p_reg_coeff75 => p_reg_coeff(75), p_reg_coeff76 => p_reg_coeff(76), p_reg_coeff77 => p_reg_coeff(77),
            p_reg_coeff78 => p_reg_coeff(78), p_reg_coeff79 => p_reg_coeff(79), p_reg_coeff80 => p_reg_coeff(80)
        );

    clk <= not clk after CLK_PERIOD/2;

    -- Tvoj originalni proces za m_ready (Backpressure)
    m_ready_proc: process
    begin
        m_axis_tready <= '1';
        wait until reset = '0';
        loop
            wait until rising_edge(clk);
            if (current_pixel_count mod IMG_W > (IMG_W - 5)) then
                m_axis_tready <= '0';
                wait for CLK_PERIOD * 15; 
                m_axis_tready <= '1';
                wait for CLK_PERIOD * 2;
            else
                m_axis_tready <= '1';
                wait for CLK_PERIOD * 8;
                m_axis_tready <= '0';
                wait for CLK_PERIOD * 1;
            end if;
        end loop;
    end process;

    -- Tvoj originalni proces za stimulus (Slanje piksela)
    stim_proc: process
        file input_file     : text open read_mode is "C:\Users\grija\PycharmProjects\pythonProject2\lena_128.txt";
        variable input_line : line;
        variable pixel_val  : integer;
        variable count      : integer := 0;
        variable seed1, seed2 : positive := 54321; 
        variable rand        : real;
        
        procedure send_pixel(constant data : in integer; constant last : in std_logic) is
        begin
            s_axis_tvalid <= '1';
            s_axis_tdata  <= std_logic_vector(to_unsigned(data, 8));
            s_axis_tlast  <= last;
            loop
                wait until rising_edge(clk);
                exit when (s_axis_tready = '1' and s_axis_tvalid = '1');
            end loop;
            s_axis_tvalid <= '0';
            s_axis_tlast  <= '0';
        end procedure;

    begin       
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait until rising_edge(clk);

        while not endfile(input_file) loop
            readline(input_file, input_line);
            while input_line'length > 0 loop
                read(input_line, pixel_val);
                
                uniform(seed1, seed2, rand);
                if (rand < 0.2) then
                    s_axis_tvalid <= '0';
                    wait for CLK_PERIOD * 2;
                    wait until rising_edge(clk);
                end if;

                count := count + 1;
                current_pixel_count <= count;

                if (count = TOTAL_PIXELS) then
                    send_pixel(pixel_val, '1');
                else
                    send_pixel(pixel_val, '0');
                end if;
                exit when count = TOTAL_PIXELS;
            end loop;
            exit when count = TOTAL_PIXELS;
        end loop;
        wait;
    end process;

    -- Tvoj originalni proces za čuvanje rezultata
    save_proc: process
        file output_file     : text open write_mode is "C:\Users\grija\PycharmProjects\pythonProject2\rezultat.txt";
        variable output_line : line;
        variable out_val     : integer;
    begin
        wait until reset = '0';
        loop
            wait until rising_edge(clk);
            if (m_axis_tvalid = '1' and m_axis_tready = '1') then
                out_val := to_integer(unsigned(m_axis_tdata));
                write(output_line, out_val);
                write(output_line, string'(" "));
                
                if (m_axis_tlast = '1') then
                    writeline(output_file, output_line);
                    file_close(output_file);
                    report "Simulacija uspesno zavrsena!";
                    wait;
                end if;
            end if;
        end loop;
    end process;

end Behavioral;