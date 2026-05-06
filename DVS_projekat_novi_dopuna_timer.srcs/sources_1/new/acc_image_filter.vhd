library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity acc_image_filter is
    generic(
           C_MAX_IMG_WIDTH : integer := 1920
           );
    Port ( 
           reset : in STD_LOGIC;
           clk : in STD_LOGIC;
           
           s_axis_data_in_tdata : in STD_LOGIC_VECTOR (7 downto 0);
           s_axis_data_in_tvalid : in STD_LOGIC;
           s_axis_data_in_tready : out STD_LOGIC;
           s_axis_data_in_tlast : in STD_LOGIC;
           
           m_axis_data_out_tdata : out STD_LOGIC_VECTOR (15 downto 0);
           m_axis_data_out_tvalid : out STD_LOGIC;
           m_axis_data_out_tready : in STD_LOGIC;
           m_axis_data_out_tlast : out STD_LOGIC;
           
           -- NOVI PORTOVI ZA KONFIGURACIJU (iz AXI Wrapper-a)
           p_reg_ctrl        : in std_logic_vector(15 downto 0);
           p_reg_radius      : in std_logic_vector(15 downto 0);
           p_reg_img_w       : in std_logic_vector(15 downto 0);
           p_reg_img_h       : in std_logic_vector(15 downto 0);
           p_reg_coeff_scale : in std_logic_vector(15 downto 0);
           
           -- Koeficijenti od 0 do 80 (ukupno 81)
            p_reg_coeff0  : in std_logic_vector(15 downto 0);
            p_reg_coeff1  : in std_logic_vector(15 downto 0);
            p_reg_coeff2  : in std_logic_vector(15 downto 0);
            p_reg_coeff3  : in std_logic_vector(15 downto 0);
            p_reg_coeff4  : in std_logic_vector(15 downto 0);
            p_reg_coeff5  : in std_logic_vector(15 downto 0);
            p_reg_coeff6  : in std_logic_vector(15 downto 0);
            p_reg_coeff7  : in std_logic_vector(15 downto 0);
            p_reg_coeff8  : in std_logic_vector(15 downto 0);
            p_reg_coeff9  : in std_logic_vector(15 downto 0);
            p_reg_coeff10 : in std_logic_vector(15 downto 0);
            p_reg_coeff11 : in std_logic_vector(15 downto 0);
            p_reg_coeff12 : in std_logic_vector(15 downto 0);
            p_reg_coeff13 : in std_logic_vector(15 downto 0);
            p_reg_coeff14 : in std_logic_vector(15 downto 0);
            p_reg_coeff15 : in std_logic_vector(15 downto 0);
            p_reg_coeff16 : in std_logic_vector(15 downto 0);
            p_reg_coeff17 : in std_logic_vector(15 downto 0);
            p_reg_coeff18 : in std_logic_vector(15 downto 0);
            p_reg_coeff19 : in std_logic_vector(15 downto 0);
            p_reg_coeff20 : in std_logic_vector(15 downto 0);
            p_reg_coeff21 : in std_logic_vector(15 downto 0);
            p_reg_coeff22 : in std_logic_vector(15 downto 0);
            p_reg_coeff23 : in std_logic_vector(15 downto 0);
            p_reg_coeff24 : in std_logic_vector(15 downto 0);
            p_reg_coeff25 : in std_logic_vector(15 downto 0);
            p_reg_coeff26 : in std_logic_vector(15 downto 0);
            p_reg_coeff27 : in std_logic_vector(15 downto 0);
            p_reg_coeff28 : in std_logic_vector(15 downto 0);
            p_reg_coeff29 : in std_logic_vector(15 downto 0);
            p_reg_coeff30 : in std_logic_vector(15 downto 0);
            p_reg_coeff31 : in std_logic_vector(15 downto 0);
            p_reg_coeff32 : in std_logic_vector(15 downto 0);
            p_reg_coeff33 : in std_logic_vector(15 downto 0);
            p_reg_coeff34 : in std_logic_vector(15 downto 0);
            p_reg_coeff35 : in std_logic_vector(15 downto 0);
            p_reg_coeff36 : in std_logic_vector(15 downto 0);
            p_reg_coeff37 : in std_logic_vector(15 downto 0);
            p_reg_coeff38 : in std_logic_vector(15 downto 0);
            p_reg_coeff39 : in std_logic_vector(15 downto 0);
            p_reg_coeff40 : in std_logic_vector(15 downto 0);
            p_reg_coeff41 : in std_logic_vector(15 downto 0);
            p_reg_coeff42 : in std_logic_vector(15 downto 0);
            p_reg_coeff43 : in std_logic_vector(15 downto 0);
            p_reg_coeff44 : in std_logic_vector(15 downto 0);
            p_reg_coeff45 : in std_logic_vector(15 downto 0);
            p_reg_coeff46 : in std_logic_vector(15 downto 0);
            p_reg_coeff47 : in std_logic_vector(15 downto 0);
            p_reg_coeff48 : in std_logic_vector(15 downto 0);
            p_reg_coeff49 : in std_logic_vector(15 downto 0);
            p_reg_coeff50 : in std_logic_vector(15 downto 0);
            p_reg_coeff51 : in std_logic_vector(15 downto 0);
            p_reg_coeff52 : in std_logic_vector(15 downto 0);
            p_reg_coeff53 : in std_logic_vector(15 downto 0);
            p_reg_coeff54 : in std_logic_vector(15 downto 0);
            p_reg_coeff55 : in std_logic_vector(15 downto 0);
            p_reg_coeff56 : in std_logic_vector(15 downto 0);
            p_reg_coeff57 : in std_logic_vector(15 downto 0);
            p_reg_coeff58 : in std_logic_vector(15 downto 0);
            p_reg_coeff59 : in std_logic_vector(15 downto 0);
            p_reg_coeff60 : in std_logic_vector(15 downto 0);
            p_reg_coeff61 : in std_logic_vector(15 downto 0);
            p_reg_coeff62 : in std_logic_vector(15 downto 0);
            p_reg_coeff63 : in std_logic_vector(15 downto 0);
            p_reg_coeff64 : in std_logic_vector(15 downto 0);
            p_reg_coeff65 : in std_logic_vector(15 downto 0);
            p_reg_coeff66 : in std_logic_vector(15 downto 0);
            p_reg_coeff67 : in std_logic_vector(15 downto 0);
            p_reg_coeff68 : in std_logic_vector(15 downto 0);
            p_reg_coeff69 : in std_logic_vector(15 downto 0);
            p_reg_coeff70 : in std_logic_vector(15 downto 0);
            p_reg_coeff71 : in std_logic_vector(15 downto 0);
            p_reg_coeff72 : in std_logic_vector(15 downto 0);
            p_reg_coeff73 : in std_logic_vector(15 downto 0);
            p_reg_coeff74 : in std_logic_vector(15 downto 0);
            p_reg_coeff75 : in std_logic_vector(15 downto 0);
            p_reg_coeff76 : in std_logic_vector(15 downto 0);
            p_reg_coeff77 : in std_logic_vector(15 downto 0);
            p_reg_coeff78 : in std_logic_vector(15 downto 0);
            p_reg_coeff79 : in std_logic_vector(15 downto 0);
            p_reg_coeff80 : in std_logic_vector(15 downto 0)
           
           );
end acc_image_filter;

architecture Behavioral of acc_image_filter is
    
    --konfiguracioni registri modula akceleratora
    signal reg_ctrl : std_logic_vector(15 downto 0);
    signal reg_radius : std_logic_vector(15 downto 0);
    signal reg_img_w : std_logic_vector(15 downto 0);
    signal reg_img_h : std_logic_vector(15 downto 0);
    signal reg_coeff_scale : std_logic_vector(15 downto 0);
    
    type reg_array_type is array (0 to 80) of std_logic_vector(15 downto 0); --velicina pogodna za 3x3, potrebno modifikovati
    signal reg_coeff : reg_array_type;
    
    --centralna aritmeticka jedinica akceleratora za sve velicine maske
    type shift_reg_type is array (0 to 8) of std_logic_vector(7 downto 0);
    type shift_regs_type is array (0 to 8) of shift_reg_type;
    signal shift_regs : shift_regs_type;
    
    --bram buffer
    --za 3x3 filtar, velicina jedne reci je 2 bajta kako bi se u nju spakovala 2 piksela
    type ram is array (0 to C_MAX_IMG_WIDTH-1) of std_logic_vector(63 downto 0);
    signal ram_buffer : ram;
    
    
    --brojac koliko je piksela primljeno
    signal kolona_count : unsigned(31 downto 0);
    signal red_count : unsigned(31 downto 0);
    
    --interni signali za sve ulaze i izlaze axi stream interfejsa
    signal s_data : STD_LOGIC_VECTOR (7 downto 0);
    signal s_valid : STD_LOGIC;
    signal s_ready : STD_LOGIC;
    signal s_last : STD_LOGIC;
    
    signal m_data : STD_LOGIC_VECTOR (15 downto 0);
    signal m_valid : STD_LOGIC;
    signal m_ready : STD_LOGIC;
    signal m_last : STD_LOGIC; 
    
    --univerzalni data pipeline za sve maske
    type data_proizvodi_type is array (0 to 8) of signed(24 downto 0);
    type data_proizvodi_matrica_type is array (0 to 8) of data_proizvodi_type;
    type data_zbir_red_type is array (0 to 8) of signed(27 downto 0);
    signal data_proizvodi : data_proizvodi_matrica_type;
    signal data_zbir_red : data_zbir_red_type;
    signal data_zbir : signed (31 downto 0);
    signal data_izlaz : signed (47 downto 0);
    
--    --data pipeline za 3x3
--    type data_proizvodi_type3 is array (0 to 8) of signed(24 downto 0);
--    signal data_proizvodi3 : data_proizvodi_type3;
--    signal data_zbir3 : signed (28 downto 0);
--    signal data_izlaz3 : signed (44 downto 0);
    
--    --data pipeline za 5x5
--    type data_proizvodi_type5 is array (0 to 24) of signed(24 downto 0);
--    signal data_proizvodi5 : data_proizvodi_type5;
--    signal data_zbir5 : signed (29 downto 0);
--    signal data_izlaz5 : signed (45 downto 0);
    
--    --data pipeline za 7x7
--    type data_proizvodi_type7 is array (0 to 48) of signed(24 downto 0);
--    signal data_proizvodi7 : data_proizvodi_type7;
--    signal data_zbir7 : signed (30 downto 0);
--    signal data_izlaz7 : signed (46 downto 0);
    
--    --data pipeline za 9x9
--    type data_proizvodi_type9 is array (0 to 80) of signed(24 downto 0);
--    signal data_proizvodi9 : data_proizvodi_type9;
--    signal data_zbir9 : signed (31 downto 0);
--    signal data_izlaz9 : signed (47 downto 0);
    
    --valid i last pipeline
    type bit_pipline is array (0 to 5) of std_logic;
    signal valid_pipline : bit_pipline;
    signal last_pipline : bit_pipline;
    
begin

     --povezivanje axi stream internih signala sa portovima
    s_data <= s_axis_data_in_tdata;
    s_valid <= s_axis_data_in_tvalid;
    s_axis_data_in_tready <= s_ready; 
    s_last <= s_axis_data_in_tlast;
    
    m_axis_data_out_tdata <= m_data;
    m_axis_data_out_tvalid <= m_valid;
    m_ready <= m_axis_data_out_tready;
    m_axis_data_out_tlast <= m_last;

    reg_ctrl <= p_reg_ctrl;
    reg_radius <= p_reg_radius;
    reg_img_w <= p_reg_img_w;
    reg_img_h <= p_reg_img_h;
    reg_coeff_scale <= p_reg_coeff_scale;
    
    -- U arhitekturi, mapiranje portova u niz reg_coeff(0 to 80)
    reg_coeff(0)  <= p_reg_coeff0;
    reg_coeff(1)  <= p_reg_coeff1;
    reg_coeff(2)  <= p_reg_coeff2;
    reg_coeff(3)  <= p_reg_coeff3;
    reg_coeff(4)  <= p_reg_coeff4;
    reg_coeff(5)  <= p_reg_coeff5;
    reg_coeff(6)  <= p_reg_coeff6;
    reg_coeff(7)  <= p_reg_coeff7;
    reg_coeff(8)  <= p_reg_coeff8;
    reg_coeff(9)  <= p_reg_coeff9;
    reg_coeff(10) <= p_reg_coeff10;
    reg_coeff(11) <= p_reg_coeff11;
    reg_coeff(12) <= p_reg_coeff12;
    reg_coeff(13) <= p_reg_coeff13;
    reg_coeff(14) <= p_reg_coeff14;
    reg_coeff(15) <= p_reg_coeff15;
    reg_coeff(16) <= p_reg_coeff16;
    reg_coeff(17) <= p_reg_coeff17;
    reg_coeff(18) <= p_reg_coeff18;
    reg_coeff(19) <= p_reg_coeff19;
    reg_coeff(20) <= p_reg_coeff20;
    reg_coeff(21) <= p_reg_coeff21;
    reg_coeff(22) <= p_reg_coeff22;
    reg_coeff(23) <= p_reg_coeff23;
    reg_coeff(24) <= p_reg_coeff24;
    reg_coeff(25) <= p_reg_coeff25;
    reg_coeff(26) <= p_reg_coeff26;
    reg_coeff(27) <= p_reg_coeff27;
    reg_coeff(28) <= p_reg_coeff28;
    reg_coeff(29) <= p_reg_coeff29;
    reg_coeff(30) <= p_reg_coeff30;
    reg_coeff(31) <= p_reg_coeff31;
    reg_coeff(32) <= p_reg_coeff32;
    reg_coeff(33) <= p_reg_coeff33;
    reg_coeff(34) <= p_reg_coeff34;
    reg_coeff(35) <= p_reg_coeff35;
    reg_coeff(36) <= p_reg_coeff36;
    reg_coeff(37) <= p_reg_coeff37;
    reg_coeff(38) <= p_reg_coeff38;
    reg_coeff(39) <= p_reg_coeff39;
    reg_coeff(40) <= p_reg_coeff40;
    reg_coeff(41) <= p_reg_coeff41;
    reg_coeff(42) <= p_reg_coeff42;
    reg_coeff(43) <= p_reg_coeff43;
    reg_coeff(44) <= p_reg_coeff44;
    reg_coeff(45) <= p_reg_coeff45;
    reg_coeff(46) <= p_reg_coeff46;
    reg_coeff(47) <= p_reg_coeff47;
    reg_coeff(48) <= p_reg_coeff48;
    reg_coeff(49) <= p_reg_coeff49;
    reg_coeff(50) <= p_reg_coeff50;
    reg_coeff(51) <= p_reg_coeff51;
    reg_coeff(52) <= p_reg_coeff52;
    reg_coeff(53) <= p_reg_coeff53;
    reg_coeff(54) <= p_reg_coeff54;
    reg_coeff(55) <= p_reg_coeff55;
    reg_coeff(56) <= p_reg_coeff56;
    reg_coeff(57) <= p_reg_coeff57;
    reg_coeff(58) <= p_reg_coeff58;
    reg_coeff(59) <= p_reg_coeff59;
    reg_coeff(60) <= p_reg_coeff60;
    reg_coeff(61) <= p_reg_coeff61;
    reg_coeff(62) <= p_reg_coeff62;
    reg_coeff(63) <= p_reg_coeff63;
    reg_coeff(64) <= p_reg_coeff64;
    reg_coeff(65) <= p_reg_coeff65;
    reg_coeff(66) <= p_reg_coeff66;
    reg_coeff(67) <= p_reg_coeff67;
    reg_coeff(68) <= p_reg_coeff68;
    reg_coeff(69) <= p_reg_coeff69;
    reg_coeff(70) <= p_reg_coeff70;
    reg_coeff(71) <= p_reg_coeff71;
    reg_coeff(72) <= p_reg_coeff72;
    reg_coeff(73) <= p_reg_coeff73;
    reg_coeff(74) <= p_reg_coeff74;
    reg_coeff(75) <= p_reg_coeff75;
    reg_coeff(76) <= p_reg_coeff76;
    reg_coeff(77) <= p_reg_coeff77;
    reg_coeff(78) <= p_reg_coeff78;
    reg_coeff(79) <= p_reg_coeff79;
    reg_coeff(80) <= p_reg_coeff80;
    
    --proces brojaca ulaznih piksela
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                kolona_count <= (others => '0');
                red_count <= (others => '0');
            else
                if (s_ready = '1' and s_valid = '1') then
                    if kolona_count = (unsigned(reg_img_w) - 1) then
                        kolona_count <= (others => '0');
                        if red_count = (unsigned(reg_img_h) - 1) then
                            red_count <= (others => '0');
                        else
                            red_count <= red_count + 1;
                        end if;
                    else
                        kolona_count <= kolona_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
   
   --proces za generisanje s_axis_data_in_tready signala kojim se omogucava primanje piksela
    process(reset, m_ready, m_valid) is
    begin
        s_ready <= '0';
    
        if(reset = '1') then
            s_ready <= '0';
        else
                s_ready <= m_axis_data_out_tready or (not m_valid);
        end if; 
    end process;
    
    
    --proces za generisanje m_valid i m_last signala; univerzalno za sve maske
    process(reset, clk) is
    begin
        if(reset = '1') then
            valid_pipline <= (others => '0');
            last_pipline  <= (others => '0');
        elsif(rising_edge(clk)) then
            
            if(m_ready = '1' or m_valid = '0') then
                                
                --generisanje m_last signala
                last_pipline(1) <= last_pipline(0);
                last_pipline(2) <= last_pipline(1);
                last_pipline(3) <= last_pipline(2);
                last_pipline(4) <= last_pipline(3);
                last_pipline(5) <= last_pipline(4);
                if (red_count = unsigned(reg_img_h) - 1 and kolona_count = unsigned(reg_img_w) - 1) and s_valid = '1' and s_ready = '1' then
                    last_pipline(0) <= '1'; -- Signaliziraj kraj na poslednjem pikselu slike
                else
                    last_pipline(0) <= '0';
                end if;
              
                --generisanje m_valid signala
                valid_pipline(1) <= valid_pipline(0);
                valid_pipline(2) <= valid_pipline(1);
                valid_pipline(3) <= valid_pipline(2);
                valid_pipline(4) <= valid_pipline(3);
                valid_pipline(5) <= valid_pipline(4);
                --provera da li je centralni piksel u kernelu ivicni ili ispada iz slike(u slucaju punjenjq ram bafera)
                if (red_count >= (2 * unsigned(reg_radius)) and red_count <= unsigned(reg_img_h) - 1 and 
                    kolona_count >= (2 * unsigned(reg_radius)) and kolona_count <= unsigned(reg_img_w) - 1) and s_valid = '1' and s_ready = '1' then
                    valid_pipline(0) <= '1';
                else
                    valid_pipline(0) <= '0';
                end if;
                
            end if;
            
        end if;
    end process;
    
    m_valid <= valid_pipline(5);
    m_last <= last_pipline(5);
    
    --proces upisa upisa piksela u ram buffer i iz ram buffera u registre aritmeticke jedinice; univerzalnoza sve maske
    process(reset, clk) is
    begin
        if(reset = '1') then
            shift_regs <= (others => (others => (others => '0')));
        elsif(rising_edge(clk)) then
            if(s_ready = '1' and s_valid = '1') then
                
                for i in 0 to 8 loop
                    for j in 8 downto 1 loop
                        shift_regs(i)(j) <= shift_regs(i)(j-1);
                    end loop;
                end loop;
                
                shift_regs(0)(0) <= s_data;
                shift_regs(1)(0) <= ram_buffer(TO_INTEGER(kolona_count))(7 downto 0);
                shift_regs(2)(0) <= ram_buffer(TO_INTEGER(kolona_count))(15 downto 8);
                shift_regs(3)(0) <= ram_buffer(TO_INTEGER(kolona_count))(23 downto 16);
                shift_regs(4)(0) <= ram_buffer(TO_INTEGER(kolona_count))(31 downto 24);
                shift_regs(5)(0) <= ram_buffer(TO_INTEGER(kolona_count))(39 downto 32);
                shift_regs(6)(0) <= ram_buffer(TO_INTEGER(kolona_count))(47 downto 40);
                shift_regs(7)(0) <= ram_buffer(TO_INTEGER(kolona_count))(55 downto 48);
                shift_regs(8)(0) <= ram_buffer(TO_INTEGER(kolona_count))(63 downto 56);
                
                ram_buffer(TO_INTEGER(kolona_count)) <= ram_buffer(TO_INTEGER(kolona_count))(55 downto 0) & s_data;
                
            end if;
        end if;
    
    end process;
    
    --univerazlni proces aritmeticke jedinice za sve maske
    process(reset, clk) is
        variable v_suma : signed(27 downto 0);
        variable v_dim  : integer range 3 to 9;
        variable v_coeff_idx : integer range 0 to 80;
    begin
        if(reset = '1') then
            data_zbir <= (others => '0');
            data_izlaz <= (others => '0');
            for i in 0 to 8 loop
                for j in 0 to 8 loop
                    data_proizvodi(i)(j) <= (others => '0');
                end loop;
            end loop;
        elsif(rising_edge(clk)) then
            if(m_ready = '1' or m_valid = '0') then
                v_dim := to_integer(unsigned(reg_radius)) * 2 + 1; --racunanje dimenzije maske
                
                --prvi pipeline nivo - mnozenje sa koeficijentima
                for i in 0 to 8 loop
                    for j in 0 to 8 loop
                        if (i < v_dim and j < v_dim) then
                            --odredjivanje koeficijenta sa kojim se mnozi trenutni piksel
                            v_coeff_idx := (v_dim * v_dim - 1) - (i * v_dim + j);
                            data_proizvodi(i)(j) <= signed('0' & shift_regs(i)(j)) * signed(reg_coeff(v_coeff_idx));
                        else
                            -- neavalidni pikseli se mnoze sa 0
                            data_proizvodi(i)(j) <= (others => '0');
                        end if;
                    end loop;
                end loop;

                
                --drugi pipeline stepen - zbir svih proizvoda
--                v_suma := (others => '0');
--                for i in 0 to 8 loop
--                    for j in 0 to 8 loop
--                        v_suma := v_suma + resize(data_proizvodi(i)(j), 32);
--                    end loop;
--                end loop;
--                data_zbir <= v_suma;

                --drugi pipline nivo - zbir proizvoda po redovima
                for i in 0 to 8 loop
                    v_suma := (others => '0');
                    for j in 0 to 8 loop
                        v_suma := v_suma + resize(data_proizvodi(i)(j), 28);
                    end loop;
                    data_zbir_red(i) <= v_suma; -- Rezultat se upisuje u registar na kraju takta
                end loop;
                
                --treci pipeline nivo - zbir svih suma redova
                data_zbir <= resize(data_zbir_red(0), 32) + data_zbir_red(1) + data_zbir_red(2) + 
                         data_zbir_red(3) + data_zbir_red(4) + data_zbir_red(5) + 
                         data_zbir_red(6) + data_zbir_red(7) + data_zbir_red(8);
                
                --cetvrti pipline stepen - mnozenje sa coeff_scale
                data_izlaz <= data_zbir * signed(reg_coeff_scale);
            
            
            end if;
        end if;
    end process;
    
    --proces aritmeticke jedinice 3x3
--    process(reset, clk) is
--    begin         
--        if(rising_edge(clk) and reset = '0') then
--            if(m_ready = '1' or m_valid = '0') then
--                --prvi pipeline nivo - mnozenje sa koeficijentima
--                data_proizvodi3(0) <= signed('0' & shift_regs(0)(0)) * signed(reg_coeff(6));
--                data_proizvodi3(1) <= signed('0' & shift_regs(0)(1)) * signed(reg_coeff(7));
--                data_proizvodi3(2) <= signed('0' & shift_regs(0)(2)) * signed(reg_coeff(8));
--                data_proizvodi3(3) <= signed('0' & shift_regs(1)(0)) * signed(reg_coeff(3));
--                data_proizvodi3(4) <= signed('0' & shift_regs(1)(1)) * signed(reg_coeff(4));
--                data_proizvodi3(5) <= signed('0' & shift_regs(1)(2)) * signed(reg_coeff(5));
--                data_proizvodi3(6) <= signed('0' & shift_regs(2)(0)) * signed(reg_coeff(0));
--                data_proizvodi3(7) <= signed('0' & shift_regs(2)(1)) * signed(reg_coeff(1));
--                data_proizvodi3(8) <= signed('0' & shift_regs(2)(2)) * signed(reg_coeff(2));
                
--                --drugi pipeline deo - sabiranje umnozaka
--                data_zbir3 <= resize(data_proizvodi3(0), 29) + data_proizvodi3(1) + data_proizvodi3(2) +
--                data_proizvodi3(3) + data_proizvodi3(4) + data_proizvodi3(5) +
--                data_proizvodi3(6) + data_proizvodi3(7) + data_proizvodi3(8);
                 
--                --treci pipline deo - mnozenje zbira sa coeff_scale
--                data_izlaz3 <= data_zbir3 * signed(reg_coeff_scale);
--            end if;            
--        end if;
--    end process;

    
    
    --process za formatiranje izlaznog podatka
    process(clk)
        variable data_shifted : signed(47 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                m_data <= (others => '0');
            else
                if(m_ready = '1' or m_valid = '0') then
                    if reg_ctrl(0) = '0' then --izlazni podatak 8bitni neoznaceni ceo broj
                        
                        --jer smo mnozili sa ne-celim brojevima coeff i coeff_scale
                        data_shifted := shift_right(data_izlaz, 27);
                        
                        --zakocavanje na maksimalnu odnosno minimalnu vrenost ukoliko je to potrebno
                        if (data_shifted > 255) then
                            m_data <= x"00FF";
                        elsif (data_shifted < 0) then
                            m_data <= x"0000";
                        else
                            m_data <= x"00" & std_logic_vector(data_shifted(7 downto 0));
                        end if;
        
                    else
                        --pomeranje za 20 u desno kako bi ostalo 7 bita za necelobrojni deo
                        data_shifted := shift_right(data_izlaz, 20);
                        m_data <= std_logic_vector(resize(data_shifted, 16));
                    end if;                   
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;