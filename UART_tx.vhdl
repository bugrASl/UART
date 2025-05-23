library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.parity_pkg.ALL;
use work.UART_FSM_pkg.all;

entity UART_tx is
    generic (
	--	HERE GENERIC IS USED IN ORDER TO BE MORE FLEXIBLE
	--	WHILE IMPLEMENTING THIS UART_RX MODULE
        c_ClkFreq     : integer      := 100_000_000;
        c_BaudRate    : integer      := 1_843_200;
        c_DataBit     : integer      := 8;
        c_StopBit     : integer      := 2;
        c_UseParity   : boolean      := true;
        c_ParityType  : parity_type  := EVEN
    );
    port (
        i_nRST      : in  std_logic;		--NEGATIVE RESET INPUT IS USED
        i_clk       : in  std_logic;
        i_tx_start  : in  std_logic;                            
        i_rx_error  : in  std_logic;                              
        i_data      : in  std_logic_vector(c_DataBit-1 downto 0);
        o_data      : out std_logic;
        o_tx_done   : out std_logic
    );
end UART_tx;

architecture Behavioral of UART_tx is
    type UART_TX_STATE is (TX_IDLE, TX_START, TX_DATA, TX_STOP);

    constant c_TicksPerBit  : integer := c_ClkFreq / c_BaudRate;
    constant TickCounterLim : integer := c_TicksPerBit - 1;
    constant StopTickLim    : integer := (c_StopBit * c_TicksPerBit) - 1;
    constant MAX_SHIFT_WIDTH: integer := c_DataBit + 1;

    signal current_state    : UART_TX_STATE                            := TX_IDLE;
    signal parity_bit       : std_logic                                := '0';
    signal TickCounter      : integer range 0 to TickCounterLim        := 0;
    signal BitCounter       : integer range 0 to MAX_SHIFT_WIDTH-1     := 0;
    signal StopCounter      : integer range 0 to c_StopBit-1           := 0;
    signal ShiftRegister    : std_logic_vector(MAX_SHIFT_WIDTH-1 downto 0) := (others => '0');

    component parity_gen is
      generic (
        N           : integer;
        parity_type : parity_type
      );
      port (
        i_data   : in  std_logic_vector(N-1 downto 0);
        o_parity : out std_logic
      );
    end component;

    procedure reset_signals(
        signal TickCounter   : out integer;
        signal BitCounter    : out integer;
        signal StopCounter   : out integer;
        signal ShiftRegister : out std_logic_vector;
        signal o_data        : out std_logic;
        signal o_tx_done     : out std_logic;
        signal current_state : out UART_TX_STATE
    ) is
    begin
        TickCounter   <= 0;
        BitCounter    <= 0;
        StopCounter   <= 0;
        ShiftRegister <= (others => '0');
        o_data        <= '1';
        o_tx_done     <= '0';
        current_state <= TX_IDLE;
    end procedure;

    procedure shift_data(signal ShiftRegister : inout std_logic_vector) is
    begin
        ShiftRegister <= '0' & ShiftRegister(ShiftRegister'high downto 1);
    end procedure;

    procedure tx_idle_state(
        signal i_tx_start   : in std_logic;
        signal i_data       : in std_logic_vector;
        signal parity_bit   : in std_logic;
        signal ShiftRegister: out std_logic_vector;
        signal BitCounter   : out integer;
        signal TickCounter  : out integer;
        signal current_state: out UART_TX_STATE;
        signal o_data       : out std_logic;
        signal o_tx_done    : out std_logic
    ) is
    begin
        o_data    <= '1';
        o_tx_done <= '0';
        if (i_tx_start = '1') then
            o_data <= '0';
            if c_UseParity then
                ShiftRegister(c_DataBit-1 downto 0) <= i_data;
                ShiftRegister(c_DataBit) <= parity_bit;
            else
                ShiftRegister(c_DataBit-1 downto 0) <= i_data;
                ShiftRegister(c_DataBit) <= '0';
            end if;
            BitCounter    <= 0;
            TickCounter   <= 0;
            current_state <= TX_START;
        end if;
    end procedure;


    procedure tx_start_state(
        signal TickCounter   : inout integer;
        signal ShiftRegister : inout std_logic_vector;
        signal current_state : out UART_TX_STATE;
        signal o_data        : out std_logic
    ) is
    begin
        if TickCounter = TickCounterLim then
            TickCounter   <= 0;
            o_data        <= ShiftRegister(0);
            shift_data(ShiftRegister);
            current_state <= TX_DATA;
        else
            TickCounter <= TickCounter + 1;
        end if;
    end procedure;

    procedure tx_data_state(
        signal TickCounter   : inout integer;
        signal BitCounter    : inout integer;
        signal ShiftRegister : inout std_logic_vector;
        signal current_state : out UART_TX_STATE;
        signal StopCounter   : out integer;
        signal o_data        : out std_logic
    ) is
    begin
        if TickCounter = TickCounterLim then
            TickCounter <= 0;
            if (c_UseParity and BitCounter = c_DataBit) or
               (not c_UseParity and BitCounter = c_DataBit-1) then
                o_data        <= '1';
                BitCounter    <= 0;
                current_state <= TX_STOP;
            else
                o_data        <= ShiftRegister(0);
                shift_data(ShiftRegister);
                BitCounter    <= BitCounter + 1;
            end if;
        else
            TickCounter <= TickCounter + 1;
        end if;
    end procedure;

    -- STOP state: on error retry or finish
    procedure tx_stop_state(
        signal i_rx_error   : in std_logic;
        signal i_data       : in std_logic_vector;
        signal parity_bit   : in std_logic;
        signal StopCounter  : inout integer;
        signal TickCounter  : inout integer;
        signal BitCounter   : out integer;
        signal ShiftRegister: inout std_logic_vector;
        signal o_data       : out std_logic;
        signal o_tx_done    : out std_logic;
        signal current_state: out UART_TX_STATE
    ) is
    begin
        o_data <= '1';
        if TickCounter = TickCounterLim then
            TickCounter <= 0;
            if StopCounter = c_StopBit-1 then
                if i_rx_error = '1' then
                    -- retry: reload and go to start bit
                    if c_UseParity then
                        ShiftRegister(c_DataBit-1 downto 0) <= i_data;
                        ShiftRegister(c_DataBit) <= parity_bit;
                    else
                        ShiftRegister(c_DataBit-1 downto 0) <= i_data;
                        ShiftRegister(c_DataBit) <= '0';
                    end if;
                    BitCounter    <= 0;
                    TickCounter   <= 0;
                    current_state <= TX_START;
                else
                    o_tx_done <= '1';
                    reset_signals(
                        TickCounter, BitCounter, StopCounter,
                        ShiftRegister, o_data, o_tx_done,
                        current_state
                    );
                end if;
            else
                StopCounter <= StopCounter + 1;
            end if;
        else
            TickCounter <= TickCounter + 1;
        end if;
    end procedure;

begin
    parity_gen_inst : parity_gen
        generic map(
            N           => c_DataBit,
            parity_type => c_ParityType
        )
        port map(
            i_data   => i_data,
            o_parity => parity_bit
        );

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_nRST = '0' then
                reset_signals(
                    TickCounter, BitCounter, StopCounter,
                    ShiftRegister, o_data, o_tx_done, current_state
                );
            else
                case current_state is
                    when TX_IDLE =>
                        tx_idle_state(
                            i_tx_start, i_data,
                            parity_bit, ShiftRegister,
                            BitCounter, TickCounter,
                            current_state, o_data, o_tx_done
                        );
                    when TX_START =>
                        tx_start_state(
                            TickCounter, ShiftRegister,
                            current_state, o_data
                        );
                    when TX_DATA =>
                        tx_data_state(
                            TickCounter, BitCounter,
                            ShiftRegister, current_state,
                            StopCounter, o_data
                        );
                    when TX_STOP =>
                        tx_stop_state(
                            i_rx_error, i_data, parity_bit,
                            StopCounter, TickCounter, BitCounter,
                            ShiftRegister, o_data, o_tx_done,
                            current_state
                        );
                end case;
            end if;
        end if;
    end process;
end Behavioral;
