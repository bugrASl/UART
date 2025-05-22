library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_display is
  port(
    clock_100Mhz   : in  std_logic;                                 -- 100 MHz system clock
    reset          : in  std_logic;                                 -- synchronous active-high reset
    data           : in  std_logic_vector(15 downto 0);             -- 4-digit hex value
    Anode_Activate : out std_logic_vector(3 downto 0);              -- active-low digit enables
    LED_out        : out std_logic_vector(6 downto 0)               -- active-low segments a…g
  );
end entity;

architecture Behavioral of seven_segment_display is

  -- Refresh counter for ~10.5 ms multiplex period (100 MHz → 4 kHz scan)
  signal refresh_counter        : unsigned(19 downto 0) := (others => '0');
  signal LED_activating_counter : unsigned(1 downto 0);

  -- Holds the current 4-bit nibble to be displayed
  signal LED_BCD                : std_logic_vector(3 downto 0);

begin

  ----------------------------------------------------------------
  -- 1) BCD → 7-segment decoder (combinational)
  ----------------------------------------------------------------
  with LED_BCD select
    LED_out <=
      "0000001" when "0000",  -- 0
      "1001111" when "0001",  -- 1
      "0010010" when "0010",  -- 2
      "0000110" when "0011",  -- 3
      "1001100" when "0100",  -- 4
      "0100100" when "0101",  -- 5
      "0100000" when "0110",  -- 6
      "0001111" when "0111",  -- 7
      "0000000" when "1000",  -- 8
      "0000100" when "1001",  -- 9
      "0000010" when "1010",  -- A
      "1100000" when "1011",  -- b
      "0110001" when "1100",  -- C
      "1000010" when "1101",  -- d
      "0110000" when "1110",  -- E
      "0111000" when others;  -- F

  ----------------------------------------------------------------
  -- 2) Refresh counter process
  ----------------------------------------------------------------
  process(clock_100Mhz, reset)
  begin
    if reset = '1' then
      refresh_counter <= (others => '0');
    elsif rising_edge(clock_100Mhz) then
      refresh_counter <= refresh_counter + 1;
    end if;
  end process;

  LED_activating_counter <= refresh_counter(19 downto 18);

  ----------------------------------------------------------------
  -- 3) 4-to-1 MUX for anodes + nibble selection
  ----------------------------------------------------------------
  process(LED_activating_counter, data)
  begin
    case LED_activating_counter is
      when "00" =>
        Anode_Activate <= "0111";            -- digit 0 (leftmost)
        LED_BCD        <= data(15 downto 12);
      when "01" =>
        Anode_Activate <= "1011";            -- digit 1
        LED_BCD        <= data(11 downto  8);
      when "10" =>
        Anode_Activate <= "1101";            -- digit 2
        LED_BCD        <= data( 7 downto  4);
      when others =>
        Anode_Activate <= "1110";            -- digit 3 (rightmost)
        LED_BCD        <= data( 3 downto  0);
    end case;
  end process;

end architecture;
