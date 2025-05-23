library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.parity_pkg.all;

entity tb_top is
--  no ports
end entity;

architecture Behavioral of tb_top is

  -- clock period for 100 MHz
  constant CLK_PERIOD : time := 10 ns;

  -- UUT signals
  signal CLK100MHZ : std_logic := '0';
  signal SW        : std_logic_vector(15 downto 0) := (others => '0');
  signal LED       : std_logic_vector(15 downto 0);
  signal SEG7      : std_logic_vector(6  downto 0);
  signal AN        : std_logic_vector(7  downto 0);

begin

  -- 1) Clock generation
  clk_proc : process
  begin
    while now < 10 ms loop   -- run for at least 10 ms
      CLK100MHZ <= '0';
      wait for CLK_PERIOD/2;
      CLK100MHZ <= '1';
      wait for CLK_PERIOD/2;
    end loop;
    wait;
  end process;

  -- 2) Instantiate your top-level
  UUT: entity work.top
    generic map(
      c_ClkFreq    => 100_000_000,
      c_BaudRate   => 1_843_200,
      c_DataBit    => 8,
      c_StopBit    => 1,
      c_UseParity  => false,
      c_ParityType => EVEN
    )
    port map(
      CLK100MHZ => CLK100MHZ,
      SW        => SW,
      LED       => LED,
      SEG7      => SEG7,
      AN        => AN
    );

  -- 3) Stimulus process
  stim_proc : process
  begin

    wait for 200 ns;

    SW(7 downto 0) <= x"19";
    SW(14)         <= '1';
    SW(13)         <= '1';
    wait for 5 ms;

    SW(7 downto 0) <= x"AB";
    SW(14)         <= '1';
    SW(13)         <= '1';
    wait for 5 ms;

    -- finish
    wait;
  end process;

end architecture;
