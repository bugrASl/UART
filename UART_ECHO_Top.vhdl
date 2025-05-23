library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.parity_pkg.all;
use work.UART_FSM_pkg.all;

entity UART_ECHO_Top is
  generic(
    c_ClkFreq   : natural      := 100_000_000;
    c_BaudRate  : natural      := 1_843_200;
    c_DataBit   : natural      := 8;
    c_StopBit   : natural      := 1;
    c_UseParity : boolean      := false;
    c_ParityType: parity_type  := EVEN
  );
  port(
    i_nRST		: in 	std_logic;                	-- active-low reset
    i_clk  		: in 	std_logic;                	-- system clock
	i_startTx  	: in 	std_logic;					-- activate Tx
	i_startRx	: in	std_logic; 					-- activate Tx
	i_data 		: in 	std_logic_vector(c_DataBit - 1 downto 0);
	o_tx_done	: out	std_logic;					-- indication of successful transmition
	o_rx_done	: out 	std_logic;					-- indication of successful receive
	o_data		: out	std_logic_vector(c_DataBit - 1 downto 0)	
  );
end UART_ECHO_Top;

architecture Behavioral of UART_ECHO_Top is

  -- Internal signals to wire RX→TX
  signal rx_error  : std_logic;
  signal o_tx_pin  : std_logic;

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
      i_data     => o_tx_pin,
	  i_rx_start => i_startRx,
      o_data     => o_data,
      o_error    => rx_error,
      o_rx_done  => o_rx_done
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
      i_tx_start  => i_startTx,
      i_rx_error  => rx_error,
      i_data      => i_data,
      o_data      => o_tx_pin,
      o_tx_done   => o_tx_done
    );
end Behavioral;
