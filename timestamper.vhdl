
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

use work.types.all;

entity timestamper is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        DATA_IN        : in  InputArrayType;
        DATA_OUT       : out TimestampedInputArrayType;
        DATA_OUT_VALID : out std_logic
    );
end entity timestamper;


architecture arch of timestamper is

    type StateType is record
            data_out       : TimestampedInputArrayType;
            data_out_valid : std_logic;
        end record StateType;

    constant reset_state : StateType := (
            data_out => (
                timestamp => (others => '1'),             -- The first valid event will have timestamp zero. 
                data      => (others => (others => '-'))
            ),
            data_out_valid => '0'
        );

    function UpdateNextState(
            current_state : in StateType;
            RESET         : in std_logic;
            DATA_IN       : in InputArrayType
        ) return StateType is

    variable state : StateType;

    begin

        if RESET = '1' then
            -- Perform a reset.
            state := reset_state;
        else
            state := (
                data_out => (
                    timestamp => std_logic_vector(unsigned(current_state.data_out.timestamp) + 1),
                    data      => DATA_IN
                ),
                data_out_valid => '1'
            );
        end if;

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET, DATA_IN);

    current_state <= next_state when rising_edge(CLK);

    DATA_OUT       <= current_state.DATA_OUT;
    DATA_OUT_VALID <= current_state.DATA_OUT_VALID;

end architecture arch;
