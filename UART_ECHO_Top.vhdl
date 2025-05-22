library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.parity_pkg.all;

entity UART_ECHO_Top is
  generic(
    c_ClkFreq   : natural      := 50_000_000;
    c_BaudRate  : natural      := 115200;
    c_DataBit   : natural      := 8;
    c_StopBit   : natural      := 1;
    c_UseParity : boolean      := false;
    c_ParityType: parity_type  := EVEN
  );
  port(
    i_nRST : in  std_logic;                -- active-low reset
    i_clk  : in  std_logic;                -- system clock
    rx_pin : in  std_logic;                -- serial RX pin
    tx_pin : out std_logic                 -- serial TX pin
  );
end UART_ECHO_Top;

architecture Behavioral of UART_ECHO_Top is

  -- Internal signals to wire RX→TX
  signal rx_data   : std_logic_vector(c_DataBit-1 downto 0);
  signal rx_error  : std_logic;
  signal rx_ready  : std_logic;
  signal rx_done   : std_logic;
  signal tx_done   : std_logic;

begin

  -- Instantiate your UART Receiver
  RX_inst : entity work.UART_rx
    generic map(
      c_ClkFreq    => c_ClkFreq,
      c_BaudRate   => c_BaudRate,
      c_DataBit    => c_DataBit,
      c_StopBit    => c_StopBit,
      c_UseParity  => c_UseParity,
      c_ParityType => c_ParityType
    )
    port map(
      i_nRST     => i_nRST,
      i_clk      => i_clk,
      i_data     => rx_pin,
      o_data     => rx_data,
      o_error    => rx_error,
      o_rx_ready => rx_ready,
      o_rx_done  => rx_done
    );

  -- Instantiate your UART Transmitter
  TX_inst : entity work.UART_tx
    generic map(
      c_ClkFreq    => c_ClkFreq,
      c_BaudRate   => c_BaudRate,
      c_DataBit    => c_DataBit,
      c_StopBit    => c_StopBit,
      c_UseParity  => c_UseParity,
      c_ParityType => c_ParityType
    )
    port map(
      i_nRST      => i_nRST,
      i_clk       => i_clk,
      -- as soon as RX reports ready (or error), fire off TX
      i_tx_start  => rx_ready,
      i_rx_ready  => rx_ready,
      i_rx_error  => rx_error,
      i_data      => rx_data,
      o_data      => tx_pin,
      o_tx_done   => tx_done
    );

end Behavioral;
