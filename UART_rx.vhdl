library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use	work.parity_pkg.all;
use work.UART_FSM_pkg.all;

entity	UART_rx	is
	generic(
	--	HERE GENERIC IS USED IN ORDER TO BE MORE FLEXIBLE
	--	WHILE IMPLEMENTING THIS UART_RX MODULE
		c_ClkFreq		:	natural		:=	100_000_000;
		c_BaudRate		:	natural		:=	1_843_200;
		c_DataBit		:	natural		:=	8;
		c_StopBit   	:	natural 	:= 	1;  
		c_UseParity		:	boolean		:=	false;
		c_ParityType	:	parity_type	:=	EVEN		
	);
	port(
		i_nRST			:	in	std_logic;		--NEGATIVE RESET INPUT IS USED
		i_clk			:	in	std_logic;
		i_data			:	in	std_logic;
		i_rx_start		:	in	std_logic;
		o_data			:	out	std_logic_vector(c_DataBit-1 downto 0);
		o_error			:	out	std_logic;
		o_rx_done		:	out	std_logic
	);
end UART_rx;

architecture Behavioral of UART_rx	is
	type	UART_RX_STATE	is	(RX_IDLE, RX_START, RX_DATA, RX_PARITY, RX_STOP, RX_DONE);

	constant	c_TicksPerBit		:	integer	:=	c_ClkFreq / c_BaudRate;
	constant 	c_SamplePoint    	: 	integer := (c_TicksPerBit-1)/2;
	constant	c_TickCounterLim	:	integer	:=	c_TicksPerBit - 1;
	constant	c_StopTickLim		:	integer	:=	(c_StopBit * c_TicksPerBit) - 1;
	constant	c_MaxShiftBit		:	integer	:=	c_DataBit + 1;
	
	signal		s_CurrentState		:	UART_RX_STATE							:=	RX_IDLE;				
	signal		TickCounter			:	integer range 0 to c_TickCounterLim		:=	0;		
	signal		BitCounter			:	integer range 0 to c_MaxShiftBit - 1	:=	0;		
	signal		StopCounter			:	integer	range 0 to c_StopBit			:=	0;		
	signal		ParityBit			:	std_logic								:=	'0';		
	
	signal		o_ShiftRegister		:	std_logic_vector(c_MaxShiftBit - 1 downto 0)	:= (others => '0');														
	signal		o_error_flag		:	std_logic										:= '0';																	
	signal		o_done_flag			:	std_logic										:= '0';
	
	component parity_gen is
        generic(
			N           : integer 		:= 	c_DataBit;
			parity_type : parity_type	:=	c_ParityType
        );
        port(	
			i_data   	: in  std_logic_vector(N-1 downto 0);
			o_parity 	: out std_logic
        );
    end component;
	
	procedure reset_signals(
		signal TickCounter       : out integer;
		signal BitCounter        : out integer;
		signal StopCounter       : out integer;
		signal o_ShiftRegister   : out std_logic_vector;
		signal o_data            : out std_logic_vector;
		signal o_rx_done         : out std_logic;
		signal s_CurrentState    : out UART_RX_STATE;
		signal o_error_flag      : out std_logic;
		signal o_done_flag       : out std_logic;
		signal ParityBit         : out std_logic
	) is
	begin
		s_CurrentState  <= RX_IDLE;
		TickCounter     <= 0;
		BitCounter      <= 0;
		StopCounter     <= 0;
		ParityBit       <= '0';
		o_ShiftRegister <= (others => '0');
		o_data          <= (others => '0');
		o_error_flag    <= '0';
		o_done_flag     <= '0';
		o_rx_done       <= '0';
	end procedure;
	
	procedure rx_idle_state(
		signal i_data       : in std_logic;
		signal i_rx_start	: in std_logic;
		signal ParityBit    : out std_logic;
		signal TickCounter  : out integer;
		signal BitCounter   : out integer;
		signal s_CurrentState  : out UART_RX_STATE;
		signal o_done_flag  : out std_logic;
		signal o_error_flag : out std_logic
	) is
	begin
		o_done_flag  <= '0';
		o_error_flag <= '0';
		if (i_data = '0') and (i_rx_start = '1') then
			BitCounter   <= 0;
			ParityBit    <= '0';
			TickCounter  <= 0;
			s_CurrentState  <= RX_START;
		else
			s_CurrentState  <= RX_IDLE;
		end if;
	end procedure;
	
	procedure rx_start_state(
		signal i_data      : in  std_logic;
		signal TickCounter : inout integer;
		signal s_CurrentState : out UART_RX_STATE;
		signal BitCounter  : out integer
	) is
	begin
		if TickCounter = c_SamplePoint then
			if i_data = '0' then
				TickCounter  <= 0;
				BitCounter   <= 0;
				s_CurrentState  <= RX_DATA;
			else
				s_CurrentState	<= RX_IDLE;
				TickCounter		<= 0;
				BitCounter		<= 0;
			end if;
		else
			TickCounter <= TickCounter + 1;
		end if;
	end procedure;
	
	procedure rx_data_state(
		signal i_data          : in std_logic;
		signal TickCounter     : inout integer;
		signal BitCounter      : inout integer;
		signal ParityBit       : inout std_logic;
		signal o_ShiftRegister : inout std_logic_vector;
		signal s_CurrentState     : out UART_RX_STATE
	) is
	begin
		if TickCounter = c_TickCounterLim then
			TickCounter  <= 0;
			o_ShiftRegister(BitCounter) <= i_data;
			if BitCounter = c_DataBit-1 then
				BitCounter	<= 0;
				if c_UseParity then
					s_CurrentState <= RX_PARITY;
				else
					s_CurrentState <= RX_STOP;
				end if;
			else
				BitCounter <= BitCounter + 1;
			end if;		
		else
			TickCounter  <= TickCounter + 1;
		end if;
	end procedure;
	
	procedure rx_parity_state(
		signal i_data       : in std_logic;
		signal TickCounter  : inout integer;
		signal ParityBit    : in std_logic;
		signal o_error_flag : inout std_logic;
		signal s_CurrentState  : out UART_RX_STATE
	) is
	begin
		if TickCounter = c_TickCounterLim then
			if ParityBit /= i_data then
				o_error_flag <= '1';
			else
				o_error_flag <= '0';
			end if;
			s_CurrentState <= RX_STOP;
		else
			TickCounter  <= TickCounter + 1;
		end if;
	end procedure;
	
	procedure rx_stop_state(
		signal i_data       : in std_logic;
		signal StopCounter  : inout integer;
		signal o_error_flag : inout std_logic;
		signal TickCounter  : inout integer;
		signal s_CurrentState  : out UART_RX_STATE
	) is
	begin
		if TickCounter = TickCounterLim then
				TickCounter <= 0;
			if StopCounter = c_StopTickLim then
				StopCounter  <= 0;
				o_data      <= o_ShiftRegister(c_DataBit-1 downto 0);
				o_done_flag <= '1';
				s_CurrentState <= RX_IDLE;
			else
				StopCounter  <= StopCounter + 1;
			end if;
		else
			TickCounter <= TickCounter + 1;
		end if;
	end procedure;
	
begin
  parity_gen_inst: parity_gen
    generic map(N => c_DataBit, parity_type => c_ParityType)
    port map(i_data => o_ShiftRegister(c_DataBit-1 downto 0), o_parity => ParityBit);

	process(i_clk)
	begin
		
		if rising_edge(i_clk) then
			if i_nRST = '0' then
				reset_signals(
					TickCounter, BitCounter, StopCounter,
					o_ShiftRegister, o_data, o_done_flag,
					s_CurrentState, o_error_flag, o_done_flag,
					ParityBit
				);
			else
				case s_CurrentState is
					when RX_IDLE   => rx_idle_state(i_data, i_rx_start, ParityBit, TickCounter, BitCounter, s_CurrentState, o_done_flag, o_error_flag);
					when RX_START  => rx_start_state(i_data, TickCounter, s_CurrentState, BitCounter);
					when RX_DATA   => rx_data_state(i_data, TickCounter, BitCounter, ParityBit, o_ShiftRegister, s_CurrentState);
					when RX_PARITY => rx_parity_state(i_data, TickCounter, ParityBit, o_error_flag, s_CurrentState);
					when RX_STOP   => rx_stop_state(i_data, StopCounter, o_error_flag, TickCounter, s_CurrentState);
				end case;
				o_error        <= o_error_flag;
				o_rx_done      <= o_done_flag;                

			end if;
		end if;
	end process;
end Behavioral;	