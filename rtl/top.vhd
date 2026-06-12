library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    port (
        clk       : in  std_logic;  -- 50 MHz clock
        reset_btn : in  std_logic;  -- KEY0, active-low (2.5V='1' not pressed, 0V='0' pressed)
        start_btn : in  std_logic;  -- KEY1, active-low (2.5V='1' not pressed, 0V='0' pressed)
        scl       : out std_logic;  -- I2C SCL pin (3.3V)
        sda       : inout std_logic -- I2C SDA pin (3.3V)
    );
end entity top;

architecture logic of top is
    -- Internal signals
    signal reset     : std_logic; -- Active-high reset (reset when '1')
    signal start_seq : std_logic; -- Active-high start (start when '1')

    -- SSD1306 controller component
    component ssd1306_controller is
        port (
            clk   : in  std_logic;
            reset : in  std_logic; -- Active-high
            start : in  std_logic; -- Active-high
            scl   : out std_logic;
            sda   : inout std_logic
        );
    end component ssd1306_controller;

begin
    -- Invert active-low buttons to active-high signals
    reset     <= not reset_btn; -- Pressed ('0') -> reset = '1'
    start_seq <= not start_btn; -- Pressed ('0') -> start_seq = '1'

    -- Instantiate the SSD1306 controller
    controller_inst : ssd1306_controller
        port map (
            clk   => clk,
            reset => reset,
            start => start_seq,
            scl   => scl,
            sda   => sda
        );

end architecture logic;