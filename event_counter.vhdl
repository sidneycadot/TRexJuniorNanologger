
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

use work.types.all;
use work.constants.all;

entity event_counter is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        --
        DATA_IN        : in  FilteredTimestampedOutputArrayType;
        DATA_IN_VALID  : in  std_logic;
        DATA_IN_READY  : out std_logic;
        --
        DATA_OUT       : out FilteredTimestampedOutputArrayType;
        DATA_OUT_VALID : out std_logic;
        DATA_OUT_READY : in  std_logic;
        --
        PACKET_OUT_BYTECOUNT : out std_logic_vector(15 downto 0);
        PACKET_OUT_CHECKSUM  : out std_logic_vector(15 downto 0);
        PACKET_OUT_VALID     : out std_logic;
        PACKET_OUT_READY     : in  std_logic
    );
end entity event_counter;


architecture arch of event_counter is

    function ones_complement_add(a: in std_logic_vector(15 downto 0); b: in std_logic_vector(15 downto 0)) return std_logic_vector is
    -- Return (a + b) mod 65535, where 0 is represented as 0xffff.
    begin
        return std_logic_vector(to_unsigned((to_integer(unsigned(a)) + to_integer(unsigned(b)) - 1) mod 65535 + 1, 16));
    end function ones_complement_add;

    function ones_complement_add_five_numbers(
        a: in std_logic_vector(15 downto 0);
        b: in std_logic_vector(15 downto 0);
        c: in std_logic_vector(15 downto 0);
        d: in std_logic_vector(15 downto 0);
        e: in std_logic_vector(15 downto 0)) return std_logic_vector is
    -- Return (a + b + c + d + e) mod 65535, where 0 is represented as 0xffff.
    variable ab: natural;
    variable cd: natural;
    variable sum: natural;
    begin
        ab := to_integer(unsigned(a)) + to_integer(unsigned(b));
        cd := to_integer(unsigned(c)) + to_integer(unsigned(d));
        sum := ab + cd +  to_integer(unsigned(e));
        return std_logic_vector(to_unsigned(sum mod 65535, 16));
    end function ones_complement_add_five_numbers;

    type StateType is record
            most_recent_data       : std_logic_vector(NUM_INPUTS-1 downto 0);
            most_recent_data_valid : std_logic;
            --
            data_in       : FilteredTimestampedOutputArrayType;
            data_in_ready : std_logic;
            --
            data_out       : FilteredTimestampedOutputArrayType;
            data_out_valid : std_logic;
            --
            packet_out_bytecount : std_logic_vector(15 downto 0);
            packet_out_checksum  : std_logic_vector(15 downto 0);
            packet_out_valid     : std_logic;
            --
            packet_delay : natural;
        end record StateType;

    constant reset_state : StateType := (
            most_recent_data => (others => '-'),
            most_recent_data_valid => '0',
            data_in => (
                first     => '-',
                timestamp => (others => '-'),
                data      => (others => '-')
            ),
            data_in_ready => '1',
            data_out => (
                first     => '-',
                timestamp => (others => '-'),
                data      => (others => '-')
            ),
            data_out_valid => '0',
            --
            packet_out_bytecount => (others => '0'),
            packet_out_checksum  => (others => '1'),
            packet_out_valid     => '0',
            --
            packet_delay => 0
        );

    function UpdateNextState(
            current_state    : in StateType;
            RESET            : in std_logic;
            DATA_IN          : in FilteredTimestampedOutputArrayType;
            DATA_IN_VALID    : in std_logic;
            DATA_OUT_READY   : in std_logic;
            PACKET_OUT_READY : in std_logic
        ) return StateType is

    variable state : StateType;
    variable event_word: std_logic_vector(63 downto 0);

    begin

        if RESET = '1' then
            -- Perform a reset.
            state := reset_state;
        else

            state := current_state;

            -- Pull in value
            if state.data_in_ready = '1' and DATA_IN_VALID = '1' then
                state.data_in := DATA_IN;
                state.data_in_ready := '0';
            end if;

            -- Push out value.
            if state.data_out_valid = '1' and DATA_OUT_READY = '1' then
                 state.data_out_valid := '0';
            end if;

            -- Transmitter accepted our packet specification.
            if state.packet_out_valid = '1' and PACKET_OUT_READY = '1' then
                state.packet_out_valid := '0';
                state.packet_out_bytecount := (others => '0');
                state.packet_out_checksum  := (others => '1');
                state.packet_delay := 1_250_000; -- limit to 100 packets/sec, unless there is more data.
            end if; 

            if state.data_in_ready = '0' and state.data_out_valid = '0' and unsigned(state.packet_out_bytecount) < 1464 and state.packet_out_valid = '0' then
                state.data_out := state.data_in;
                state.data_out_valid := '1';
                state.data_in_ready := '1';
                state.packet_out_bytecount := std_logic_vector(unsigned(state.packet_out_bytecount) + 8); 

                event_word := state.data_in.first & state.data_in.timestamp & state.data_in.data;
            
                state.packet_out_checksum := ones_complement_add_five_numbers(
                    state.packet_out_checksum,
                    event_word(63 downto 48),
                    event_word(47 downto 32),
                    event_word(31 downto 16),
                    event_word(15 downto  0)
                );
            end if;

            if unsigned(state.packet_out_bytecount) = 1464 then
                state.packet_delay := 0;
            end if;

            if state.packet_delay = 0 then
                state.packet_out_valid := '1';
            else
                state.packet_out_valid := '0';
                state.packet_delay := state.packet_delay - 1;
            end if;

        end if; -- we're not resetting.

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET, DATA_IN, DATA_IN_VALID, DATA_OUT_READY, PACKET_OUT_READY);

    current_state <= next_state when rising_edge(CLK);

    DATA_IN_READY  <= current_state.data_in_ready;
    DATA_OUT       <= current_state.data_out;
    DATA_OUT_VALID <= current_state.data_out_valid;

    PACKET_OUT_BYTECOUNT <= current_state.packet_out_bytecount;
    PACKET_OUT_CHECKSUM  <= current_state.packet_out_checksum;
    PACKET_OUT_VALID     <= current_state.packet_out_valid;

end architecture arch;
