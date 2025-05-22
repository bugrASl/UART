library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use	work.parity_pkg.all;

entity	parity_gen	is
	generic(
				N			:	integer	:=	4;
				parity_type	:	parity_type
			);
	port	(
				i_data		:	in	std_logic_vector(N-1 downto	0);
				o_parity	:	out	std_logic
			);
end	parity_gen;

architecture	RTL	of	parity_gen	is
begin
	process	(i_data)
		variable	tmp		:	std_logic;
	begin
		tmp		:=	'0';
		for	i	in	i_data'low	to	i_data'high	loop
			tmp		:=	tmp	xor	i_data(i);
		end	loop;
		
		if	(parity_type	=	EVEN) then
			o_parity	<=	tmp;
		else
			o_parity	<=	not	tmp;
		end if;
	end	process;
end	RTL;
