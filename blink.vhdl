
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

entity blink is
    port (
        CLK       : in  std_logic;
        RESET     : in  std_logic;
        BLINK_OUT : out std_logic
    );
end entity blink;


architecture arch of blink is

    type CounterType is range 0 to 124_999_999;

    type StateType is record
            counter : CounterType;
            blink_out : std_logic;
        end record StateType;

    constant reset_state : StateType := (
            counter   => 0,
            blink_out => '1'
        );

    function UpdateNextState(
            current_state  : in StateType;
            RESET          : in std_logic
        ) return StateType is

    variable state : StateType;

    begin

        if RESET = '1' then
            -- Perform a reset.
            state := reset_state;
        else

            state := current_state;

            if state.counter = CounterType'high then
                state.counter := 0;
            else
                state.counter := state.counter + 1;
            end if;

            state.blink_out := '1' when state.counter <= 124_999 else '0';

        end if;

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET);

    current_state <= next_state when rising_edge(CLK);

    BLINK_OUT  <= current_state.blink_out;

end architecture arch;
