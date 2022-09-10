library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.types.all;

entity events_to_octets is

    port (
        CLK   : in std_logic;
        RESET : in std_logic;
        --
        DATA_IN        : in  FilteredTimestampedOutputArrayType;
        DATA_IN_VALID  : in  std_logic;
        DATA_IN_READY  : out std_logic;
        --
        DATA_OUT        : out std_logic_vector(7 downto 0);
        DATA_OUT_VALID  : out std_logic;
        DATA_OUT_READY  : in  std_logic
    );

end entity events_to_octets;


architecture arch of events_to_octets is

    type StateType is record
          index: natural;
          --
          data_in        : std_logic_vector(63 downto 0);
          data_in_ready  : std_logic;
          --
          data_out       : std_logic_vector(7 downto 0);
          data_out_valid : std_logic;
    end record StateType;

    constant reset_state : StateType := (
          index          => 0,
          data_in        => (others => '-'),
          data_in_ready  => '1',
          data_out       => (others => '-'),
          data_out_valid => '0'
      );

    function UpdateNextState(
            current_state          : in StateType;
            RESET                  : in std_logic;
            DATA_IN                : in std_logic_vector(63 downto 0);
            DATA_IN_VALID          : in std_logic;
            DATA_OUT_READY         : in std_logic
        ) return StateType is

    variable state: StateType;

    begin
        -- Calculate next state based on current state and inputs.
        if RESET = '1' then
            -- Handle synchronous reset.
            state := reset_state;
        else
            -- Start from current state.
            state := current_state;

            if state.data_in_ready = '1' and DATA_IN_VALID = '1' then
                state.data_in := DATA_IN;                
                state.data_in_ready := '0';
                state.index := 7;
            end if;

            if state.data_out_valid = '1' and DATA_OUT_READY = '1' then
                state.data_out_valid := '0';
            end if;

            if state.data_out_valid = '0' then
                if state.data_in_ready = '0' then
                    state.data_out := state.data_in(63 downto 56);
                    state.data_out_valid := '1';
                    if state.index = 0 then
                        state.data_in_ready := '1';
                    else
                        state.index := state.index - 1;
                        state.data_in := state.data_in(55 downto 0) & x"00";
                    end if;
                end if;
            end if;

        end if;

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(
            current_state,
            RESET,
            DATA_IN.first & DATA_IN.timestamp & DATA_IN.data,
            DATA_IN_VALID,
            DATA_OUT_READY
        );

    current_state <= next_state when rising_edge(CLK);

    DATA_IN_READY  <= current_state.data_in_ready;
    DATA_OUT       <= current_state.data_out;
    DATA_OUT_VALID <= current_state.data_out_valid;

end architecture arch;
