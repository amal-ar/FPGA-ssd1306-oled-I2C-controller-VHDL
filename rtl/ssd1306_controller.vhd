library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ssd1306_controller is
    port (
        clk         : in  std_logic;  -- 50 MHz clock
        reset       : in  std_logic;  -- Active-high reset
        start       : in  std_logic;  -- Active-high start
        scl         : out std_logic;  -- I2C clock line
        sda         : inout std_logic -- I2C data line
    );
end entity ssd1306_controller;

architecture logic of ssd1306_controller is
    -- SSD1306 constants
    constant SLAVE_ADDR    : std_logic_vector(7 downto 0) := "01111000"; -- 0x78
    constant CONTROL_CMD   : std_logic_vector(7 downto 0) := "00000000"; -- 0x00
    constant CONTROL_DATA  : std_logic_vector(7 downto 0) := "01000000"; -- 0x40

    -- Initialization commands
    type cmd_array is array (0 to 30) of std_logic_vector(7 downto 0);
    constant INIT_CMDS : cmd_array := (
        0  => x"AE", 1  => x"D5", 2  => x"80", 3  => x"A8", 4  => x"3F",
        5  => x"D3", 6  => x"00", 7  => x"40", 8  => x"8D", 9  => x"14",
        10 => x"20", 11 => x"00", 12 => x"A1", 13 => x"C8", 14 => x"DA",
        15 => x"12", 16 => x"81", 17 => x"CF", 18 => x"D9", 19 => x"F1",
        20 => x"DB", 21 => x"40", 22 => x"A4", 23 => x"A6", 24 => x"AF",
        25 => x"21", 26 => x"00", 27 => x"7F", 28 => x"22", 29 => x"00",
        30 => x"07"
    );

    -- Sine table for 32 samples (amplitude 15 pixels, centered at row 32)
    type integer_vector is array (natural range <>) of integer;
    constant SINE_TABLE : integer_vector(0 to 31) := (
        0, 3, 6, 8, 11, 12, 14, 15, 15, 15, 14, 12, 11, 8, 6, 3,
        0, -3, -6, -8, -11, -12, -14, -15, -15, -15, -14, -12, -11, -8, -6, -3
    );
	 
    -- State machine
    type state_type is (IDLE, SEND_INIT_CMD, WAIT_INIT_CMD, SEND_DATA_BYTE, WAIT_DATA_BYTE, DONE, ERROR);
    signal state : state_type;

    -- Counters and data
    signal cmd_index    : integer range 0 to 30;
    signal data_count   : integer range 0 to 1023;
    signal pattern_data : std_logic_vector(7 downto 0);

    -- I2C interface signals
    signal base_address : std_logic_vector(7 downto 0);
    signal data_byte    : std_logic_vector(7 downto 0);
    signal start_seq    : std_logic;
    signal end_seq      : std_logic;
    signal ack_n        : std_logic;

    -- Timeout counter
    signal timeout_cnt : integer range 0 to 1000000; -- ~25ms at 40 MHz
    constant TIMEOUT_MAX : integer := 1000000;

    -- I2C component
    component I2C is
        generic (
            CLKFREQ : positive := 50000000;
            I2CFREQ : positive := 100000
        );
        port (
            CLK           : in  std_logic;
            RESET         : in  std_logic; -- Active-low
            SCL           : out std_logic;
            SDA           : inout std_logic;
            SLAVE_ADDRESS : in  std_logic_vector(7 downto 0);
            BASE_ADDRESS  : in  std_logic_vector(7 downto 0);
            DATA_BYTE     : in  std_logic_vector(7 downto 0);
            START_SEQ     : in  std_logic;
            COMP_SEQ      : out std_logic;
            ACK_N         : out std_logic
        );
    end component I2C;

begin
    -- I2C instantiation with reset fix
    I2C_inst : I2C
        generic map (
            CLKFREQ => 50000000,
            I2CFREQ => 100000
        )
        port map (
            CLK           => clk,
            RESET         => reset,
            SCL           => scl,
            SDA           => sda,
            SLAVE_ADDRESS => SLAVE_ADDR,
            BASE_ADDRESS  => base_address,
            DATA_BYTE     => data_byte,
            START_SEQ     => start,
            COMP_SEQ      => end_seq,
            ACK_N         => ack_n
        );

    -- Pattern generation:
	 
    -- Pattern generation: smoother sine wave centered at row 32, amplitude 15, period 128
    process (data_count)
        variable column     : integer range 0 to 127;
        variable page       : integer range 0 to 7;
        variable row        : integer; -- Row within page
        variable sine_idx   : integer range 0 to 31;
        variable y          : integer; -- Sine wave center row
        variable data_bits  : std_logic_vector(7 downto 0);
    begin
        column := data_count mod 128; -- Column within page
        page := data_count / 128; -- Page number (0 to 7)

        -- Compute sine table index (32 samples over 128 columns)
        sine_idx := (column / 4) mod 32;

        -- Calculate sine wave center: row 32 + sine offset
        y := 32 + SINE_TABLE(sine_idx); -- Rows 17 to 47

        -- Initialize data bits to black
        data_bits := (others => '0');

        -- Set bits for sine wave (3-pixel thickness: y-1 to y+1)
        for i in 0 to 7 loop
            row := page * 8 + i; -- Row number (0 to 63)
            if row >= y - 1 and row <= y + 1 then
                data_bits(i) := '1'; -- Set bit for row within sine wave
            end if;
        end loop;

        pattern_data <= data_bits;
    end process;
	 
    -- State machine
    process (clk, reset)
    begin
        if reset = '1' then
            state        <= IDLE;
            cmd_index    <= 0;
            data_count   <= 0;
            start_seq    <= '0';
            base_address <= (others => '0');
            data_byte    <= (others => '0');
            timeout_cnt  <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    timeout_cnt <= 0;
                    if start = '1' then
                        state        <= SEND_INIT_CMD;
                        cmd_index    <= 0;
                        base_address <= CONTROL_CMD;
                        data_byte    <= INIT_CMDS(0);
                    end if;

                when SEND_INIT_CMD =>
                    start_seq   <= '1';
                    state       <= WAIT_INIT_CMD;
                    timeout_cnt <= 0;

                when WAIT_INIT_CMD =>
                    start_seq <= '0';
                    timeout_cnt <= timeout_cnt + 1;
                    if end_seq = '1' then
                        if ack_n = '1' then
                            state <= ERROR; -- I2C error
                        elsif cmd_index < 30 then
                            cmd_index    <= cmd_index + 1;
                            data_byte    <= INIT_CMDS(cmd_index + 1);
                            state        <= SEND_INIT_CMD;
                        else
                            state        <= SEND_DATA_BYTE;
                            data_count   <= 0;
                            base_address <= CONTROL_DATA;
                            data_byte    <= pattern_data;
                        end if;
                    elsif timeout_cnt >= TIMEOUT_MAX then
                        state <= ERROR;
                    end if;

                when SEND_DATA_BYTE =>
                    start_seq   <= '1';
                    state       <= WAIT_DATA_BYTE;
                    timeout_cnt <= 0;

                when WAIT_DATA_BYTE =>
                    start_seq <= '0';
                    timeout_cnt <= timeout_cnt + 1;
                    if end_seq = '1' then
                        if ack_n = '1' then
                            state <= ERROR;
                        elsif data_count < 1023 then
                            data_count <= data_count + 1;
                            data_byte  <= pattern_data;
                            state      <= SEND_DATA_BYTE;
                        else
                            state <= DONE;
                        end if;
                    elsif timeout_cnt >= TIMEOUT_MAX then
                        state <= ERROR;
                    end if;

                when DONE =>
                    timeout_cnt <= 0;
                    state <= IDLE; -- Allow new start triggers

                when ERROR =>
                    start_seq <= '0';
                    state <= IDLE; -- Recover to allow retry
            end case;
        end if;
    end process;

end architecture logic;