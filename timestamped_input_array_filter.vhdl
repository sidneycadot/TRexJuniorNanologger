
library ieee;
use ieee.std_logic_1164.all;

use work.types.all;
use work.constants.all;

entity timestamped_input_array_filter is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        DATA_IN        : in  TimestampedInputArrayType;
        DATA_IN_VALID  : in  std_logic;
        DATA_OUT       : out FilteredTimestampedInputArrayType;
        DATA_OUT_VALID : out std_logic;
        DATA_OUT_READY : in  std_logic
    );
end entity timestamped_input_array_filter;


architecture arch of timestamped_input_array_filter is

    type StateType is record
            most_recent_bits       : std_logic_vector(NUM_INPUTS - 1 downto 0);
            most_recent_bits_valid : std_logic;
            --
            data_out       : FilteredTimestampedInputArrayType;
            data_out_valid : std_logic;
        end record StateType;

    constant reset_state : StateType := (
            most_recent_bits => (others => '-'),
            most_recent_bits_valid => '0',
            data_out => (
                first     => '-',
                timestamp => (others => '-'),
                data      => (others => (others => '-'))
            ),
            data_out_valid => '0'
        );

    function UpdateNextState(
            current_state  : in StateType;
            RESET          : in std_logic;
            DATA_IN        : in TimestampedInputArrayType;
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

            -- Push out value.
            if state.data_out_valid = '1' and DATA_OUT_READY = '1' then
                 state.data_out_valid := '0';
            end if;

            if DATA_IN_VALID = '1' then

                -- Our input is valid; we want to process it.

                if (state.most_recent_bits_valid = '0') or (ExpandBitsToInputArray(state.most_recent_bits) /= DATA_IN.data) then

                    -- We *want* to publish it.

                    if state.data_out_valid = '0' then
                        -- We *can* publish the data; do it.
                        state.data_out := (
                            first     => not state.most_recent_bits_valid,
                            timestamp => DATA_IN.timestamp,
                            data      => DATA_IN.data
                        );
                        state.data_out_valid := '1';
                        state.most_recent_bits := SelectBits(DATA_IN.data, YOUNGEST_BIT);
                        state.most_recent_bits_valid := '1';
                    else
                        -- We *cannot* publish the data.
                        -- On the next cycle, always try to publish.
                        state.most_recent_bits := (others => '-');
                        state.most_recent_bits_valid := '0';
                    end if;

                end if; -- we want to publish data.
            end if; -- we have valid input data.
        end if; -- we're not resetting.

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET, DATA_IN, DATA_IN_VALID, DATA_OUT_READY);

    current_state <= next_state when rising_edge(CLK);

    DATA_OUT       <= current_state.DATA_OUT;
    DATA_OUT_VALID <= current_state.DATA_OUT_VALID;

end architecture arch;
