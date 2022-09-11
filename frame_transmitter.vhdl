
-- The frame_transmitter receives octets on its DATA_IN port, and transmits octets to the DATA_OUT port.
--
-- While doing this, it maintains a count of octets that it has pushed downstream for processing, along
-- with their one-complement checksum.
--

library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

use work.constants.all;

entity frame_transmitter is
    port (
        CLK            : in  std_logic;
        RESET          : in  std_logic;
        --
        DATA_IN        : in  std_logic_vector(7 downto 0);
        DATA_IN_VALID  : in  std_logic;
        DATA_IN_READY  : out std_logic;
        --
        DATA_OUT       : out std_logic_vector(7 downto 0);
        DATA_OUT_VALID : out std_logic;
        DATA_OUT_READY : in  std_logic;
        --
        FRAME_METADATA_OUT_OCTET_COUNT : out std_logic_vector(15 downto 0);
        FRAME_METADATA_OUT_CHECKSUM    : out std_logic_vector(15 downto 0);
        FRAME_METADATA_OUT_VALID       : out std_logic;
        FRAME_METADATA_OUT_READY       : in  std_logic
    );
end entity frame_transmitter;


architecture arch of frame_transmitter is

    --function ones_complement_add(a: in std_logic_vector(15 downto 0); b: in std_logic_vector(15 downto 0)) return std_logic_vector is
    ---- Return (a + b) mod 65535, where 0 is represented as 0xffff.
    --begin
    --    return std_logic_vector(to_unsigned((to_integer(unsigned(a)) + to_integer(unsigned(b)) - 1) mod 65535 + 1, 16));
    --end function ones_complement_add;

    function ones_complement_add(a: in std_logic_vector(15 downto 0); b: in std_logic_vector(15 downto 0)) return std_logic_vector is
    -- Return (a + b) mod 65535, where 0 is represented as 0xffff.
    variable r:  std_logic_vector(15 downto 0);
    begin
        if a < not(b) then
            r := std_logic_vector(unsigned(a) + unsigned(b));
        else
            r := std_logic_vector(unsigned(a) - unsigned(not b));
        end if;
        if r = x"0000" then
            r := x"ffff";
        end if;
        return r;
    end function ones_complement_add;

    type AgeCounterType is range 0 to 12_499_999;

    type StateType is record
            --
            data_in       : std_logic_vector(7 downto 0);
            data_in_ready : std_logic;
            --
            data_out       : std_logic_vector(7 downto 0);
            data_out_valid : std_logic;
            --
            frame_metadata_out_octet_count : std_logic_vector(15 downto 0);
            frame_metadata_out_checksum    : std_logic_vector(15 downto 0);
            frame_metadata_out_valid       : std_logic;
            --
            age_counter : AgeCounterType;
        end record StateType;

    constant reset_state : StateType := (
            --
            data_in       => (others => '-'),
            data_in_ready => '1',
            --
            data_out       => (others => '-'),
            data_out_valid => '0',
            --
            frame_metadata_out_octet_count => (others => '0'),
            frame_metadata_out_checksum    => (others => '1'),
            frame_metadata_out_valid       => '0',
            --
            age_counter => 0
        );

    function UpdateNextState(
            current_state            : in StateType;
            RESET                    : in std_logic;
            DATA_IN                  : in std_logic_vector(7 downto 0);
            DATA_IN_VALID            : in std_logic;
            DATA_OUT_READY           : in std_logic;
            FRAME_METADATA_OUT_READY : in std_logic
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
                 state.data_out := (others => '-'); 
            end if;

            -- The transmitter accepted our packet specification.
            if state.frame_metadata_out_valid = '1' and FRAME_METADATA_OUT_READY = '1' then
                state.frame_metadata_out_octet_count := (others => '0');
                state.frame_metadata_out_checksum    := (others => '1');
                state.age_counter := 0;
            end if;

            if state.data_in_ready = '0' and state.data_out_valid = '0' and to_integer(unsigned(state.frame_metadata_out_octet_count)) /= 1464 then
                if  state.frame_metadata_out_octet_count(0) = '0' then
                    state.frame_metadata_out_checksum := ones_complement_add(state.frame_metadata_out_checksum, state.data_in & x"00");
                else
                    state.frame_metadata_out_checksum := ones_complement_add(state.frame_metadata_out_checksum, x"00" & state.data_in);
                end if;
                state.frame_metadata_out_octet_count := std_logic_vector(unsigned(state.frame_metadata_out_octet_count) + 1);
                state.data_out := state.data_in;
                state.data_in := (others => '-');
                state.data_in_ready := '1';
                state.data_out_valid := '1';
            end if;

            -- Determine new values for:
            --    state.data_in_ready
            --    state.data_out_valid
            --    frame_metadata_out_valid

            if (state.frame_metadata_out_octet_count(2 downto 0) = "000") and ((to_integer(unsigned(state.frame_metadata_out_octet_count)) = 1464) or (state.age_counter = AgeCounterType'high)) then
                state.frame_metadata_out_valid := '1';
            else
                state.frame_metadata_out_valid := '0';
            end if; 

            if state.age_counter /= AgeCounterType'high then
                state.age_counter := state.age_counter + 1;
            end if;

        end if; -- we're not resetting.

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, RESET, DATA_IN, DATA_IN_VALID, DATA_OUT_READY, FRAME_METADATA_OUT_READY);

    current_state <= next_state when rising_edge(CLK);

    DATA_IN_READY  <= current_state.data_in_ready;
    DATA_OUT       <= current_state.data_out;
    DATA_OUT_VALID <= current_state.data_out_valid;

    FRAME_METADATA_OUT_OCTET_COUNT <= current_state.frame_metadata_out_octet_count;
    FRAME_METADATA_OUT_CHECKSUM    <= current_state.frame_metadata_out_checksum;
    FRAME_METADATA_OUT_VALID       <= current_state.frame_metadata_out_valid;

end architecture arch;
