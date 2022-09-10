
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

use work.types.all;
use work.constants.all;

entity event_filter is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        DATA_IN        : in  FilteredTimestampedOutputArrayType;
        DATA_IN_VALID  : in  std_logic;
        DATA_IN_READY  : out std_logic;
        DATA_OUT       : out FilteredTimestampedOutputArrayType;
        DATA_OUT_VALID : out std_logic;
        DATA_OUT_READY : in  std_logic
    );
end entity event_filter;

architecture arch of event_filter is

    type StateType is record
            most_recent_data       : std_logic_vector(NUM_INPUTS-1 downto 0);
            most_recent_data_valid : std_logic;
            --
            data_in       : FilteredTimestampedOutputArrayType;
            data_in_ready : std_logic;
            --
            data_out       : FilteredTimestampedOutputArrayType;
            data_out_valid : std_logic;
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
            data_out_valid => '0'
        );

    function UpdateNextState(
            current_state  : in StateType;
            RESET          : in std_logic;
            DATA_IN        : in FilteredTimestampedOutputArrayType;
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
            end if;

            -- Push out value.
            if state.data_out_valid = '1' and DATA_OUT_READY = '1' then
                 state.data_out_valid := '0';
            end if;

            if state.data_in_ready = '0' then

                -- We have data. Check if it is publish-worthy.

                if state.data_in.first = '1' then
                    state.most_recent_data_valid := '0';
                    state.most_recent_data := (others => '-');
                end if;

                if (state.most_recent_data_valid = '0') or (state.data_in.data /= state.most_recent_data) then

                    -- We want to publish, but can we?

                    if state.data_out_valid = '0' then

                        -- Yes we can!

                        state.data_out := (
                            first     => not state.most_recent_data_valid,
                            timestamp => state.data_in.timestamp,
                            data      => state.data_in.data
                        );

                        state.data_out_valid := '1';

                        state.most_recent_data := state.data_in.data;
                        state.most_recent_data_valid := '1';

                        -- Discard input data.
                        state.data_in := (
                            first     => '-',
                            timestamp => (others => '-'),
                            data      => (others => '-')
                        );
                        state.data_in_ready := '1';

                    else
                        -- No we cannot. pause until the next cycle.
                    end if;
        
                else

                    -- Input data is not publish-worthy. Discard it.
                    state.data_in := (
                        first     => '-',
                        timestamp => (others => '-'),
                        data      => (others => '-')
                    );
                    state.data_in_ready := '1';

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
