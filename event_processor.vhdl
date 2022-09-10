
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

use work.types.all;
use work.constants.all;

entity event_processor is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        DATA_IN        : in  FilteredTimestampedInputArrayType;
        DATA_IN_VALID  : in  std_logic;
        DATA_IN_READY  : out std_logic;
        DATA_OUT       : out FilteredTimestampedOutputArrayType;
        DATA_OUT_VALID : out std_logic;
        DATA_OUT_READY : in  std_logic
    );
end entity event_processor;


architecture arch of event_processor is

    type StateType is record
            process_bit : BitIndex;
            --
            data_in       : FilteredTimestampedInputArrayType;
            data_in_ready : std_logic;
            --
            data_out       : FilteredTimestampedOutputArrayType;
            data_out_valid : std_logic;
        end record StateType;

    constant reset_state : StateType := (
            process_bit => OLDEST_BIT,
            data_in => (
                first     => '-',
                timestamp => (others => '-'),
                data      => (others => (others => '-'))
            ),
            data_in_ready => '1',
            data_out => (
                first     => '-',
                timestamp => (others => '-'),
                data      => (others => '-')
            ),
            data_out_valid => '0'
        );

    function UpdateNextState(
            current_state  : in StateType;
            RESET          : in std_logic;
            DATA_IN        : in FilteredTimestampedInputArrayType;
            DATA_IN_VALID  : in std_logic;
            DATA_OUT_READY : in std_logic
        ) return StateType is

    variable state : StateType;

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
                state.process_bit := OLDEST_BIT; -- This is already true.
            end if;

            -- Push out value.
            if state.data_out_valid = '1' and DATA_OUT_READY = '1' then
                 state.data_out_valid := '0';
            end if;

            if state.data_in_ready = '0' and state.data_out_valid = '0' then

                -- We want to publish and we can publish; so, publish!

                state.data_out := (
                    first     => state.data_in.first,
                    timestamp => state.data_in.timestamp & std_logic_vector(to_unsigned(natural(state.process_bit), 3)),
                    data      => SelectBits(state.data_in.data, state.process_bit)
                );

                state.data_in.first := '0'; -- Any bit except the first one will always have first = '0'.
                state.data_out_valid := '1';

                if state.process_bit = YOUNGEST_BIT then
                    state.process_bit := OLDEST_BIT;
                    state.data_in_ready := '1'; -- Done processing the data; we're willing to accept new incoming data.
                else
                    state.process_bit := BitIndex'succ(state.process_bit);
                end if;

            end if; -- we have data to process.

        end if; -- we're not resetting.

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET, DATA_IN, DATA_IN_VALID, DATA_OUT_READY);

    current_state <= next_state when rising_edge(CLK);

    DATA_IN_READY  <= current_state.data_in_ready;
    DATA_OUT       <= current_state.data_out;
    DATA_OUT_VALID <= current_state.data_out_valid;

end architecture arch;
