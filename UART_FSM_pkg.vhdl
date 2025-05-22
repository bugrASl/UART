library	IEEE;
use	IEEE.STD_LOGIC_1164.all;

package	UART_FSM_pkg	is
	type	STATE	is	(S_IDLE	,	S_START	,	S_DATA	,	S_STOP);
end	package;
