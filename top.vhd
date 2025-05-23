library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.parity_pkg.all;
use work.UART_FSM_pkg.all;

entity top is
	generic(
		c_ClkFreq   : natural      := 100_000_000;
		c_BaudRate  : natural      := 1_843_200;
		c_DataBit   : natural      := 8;
		c_StopBit   : natural      := 1;
		c_UseParity : boolean      := false;
		c_ParityType: parity_type  := EVEN
	);
	port(
		CLK100MHZ	:	in std_logic;
		SW			:	in std_logic_vector(15 downto 0);
		LED			:	out std_logic_vector(15 downto 0);
		SEG7		:	out std_logic_vector(6 downto 0);
		AN			:	out std_logic_vector(7 downto 0)		
	);
end top;

architecture Behavioral of top is
	signal i_data_reg 	: std_logic_vector(c_DataBit-1 downto 0);
	signal o_data_reg 	: std_logic_vector(c_DataBit-1 downto 0);
	signal display_sig : std_logic_vector(15 downto 0);
begin
	AN(7 downto 4) 		<= (others=>'1');
	LED(15)				<= '0';
	LED(12 downto 0)	<= (others=>'1');
	
	i_data_reg <= SW(c_DataBit-1 downto 0);
	display_sig <= o_data_reg & i_data_reg;

	UART_ECHO: entity work.UART_ECHO_Top
		generic map(
			c_ClkFreq		=>	c_ClkFreq,   	
			c_BaudRate      =>	c_BaudRate,  
			c_DataBit       =>	c_DataBit,   
			c_StopBit       =>	c_StopBit,   
			c_UseParity     =>	c_UseParity, 
			c_ParityType    =>	c_ParityType			
		)
		port map(
			i_nRST		    =>	SW(15),
		    i_clk  		    =>	CLK100MHZ,
		    i_startTx  	    =>	SW(14),
		    i_startRx		=>	SW(13),
			i_data 			=>	i_data_reg,
			o_tx_done		=>	LED(14),
			o_rx_done		=>	LED(13),
			o_data			=>	o_data_reg			
		);
		
	SEG7_disp: entity work.seven_segment_display
		port map(
			clock_100Mhz  	=>	CLK100MHZ,
		    reset         	=>	SW(15),
		    data          	=>	display_sig,
		    Anode_Activate	=>	AN(3 downto 0),
		    LED_out    		=>	SEG7
		);
end Behavioral;
	
	