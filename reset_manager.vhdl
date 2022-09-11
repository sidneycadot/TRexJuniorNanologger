
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.types.all;
use work.constants.all;

entity reset_manager is
    port (
        XTAL_CLK_12MHz : in  std_logic;
        SAMPLE_CLK     : in  std_logic;
        TX_CLK_125_MHz : in  std_logic;
        --
        ASYNC_MASTER_RESET : in std_logic;
        --
        INPUT_SECTION_RESET     : out std_logic; -- synchronous to SAMPLE_CLK
        ASYNCHRONOUS_FIFO_RESET : out std_logic; -- synchronous to SAMPLE_CLK
        OUTPUT_SECTION_RESET    : out std_logic  -- synchronous to TX_CLK_125_MHz
    );
end entity reset_manager;


architecture arch of reset_manager is

    type CounterType is range 0 to 59_999; -- 5 ms

    type StateType is record
            counter : CounterType;
            --
            cmd_input_section_reset     : std_logic;
            cmd_asynchronous_fifo_reset : std_logic;
            cmd_output_section_reset    : std_logic;
         end record StateType;

    constant reset_state : StateType := (
            counter => 0,
            --
            cmd_input_section_reset     => '1',
            cmd_asynchronous_fifo_reset => '1',
            cmd_output_section_reset    => '1'
        );

    function UpdateNextState(
            current_state : in StateType;
            MASTER_RESET  : in std_logic
        ) return StateType is

    variable state : StateType;

    begin

        if MASTER_RESET = '1' then
            -- Perform a reset.
            state := reset_state;
        else

            state := current_state;

            if state.counter /= CounterType'high then
                state.counter := state.counter + 1;
            end if;

            state.cmd_output_section_reset    := '1' when state.counter < 1 * 12000 else '0';
            state.cmd_asynchronous_fifo_reset := '1' when state.counter < 1 * 12000 else '0';
            state.cmd_input_section_reset     := '1' when state.counter < 2 * 12000 else '0';

        end if; -- we're not resetting.

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

signal MASTER_RESET : std_logic;

begin

    next_state <= UpdateNextState(current_state, MASTER_RESET);

    current_state <= next_state when rising_edge(XTAL_CLK_12MHz);

    master_reset_cdc : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 0  -- DECIMAL; 0=do not register input, 1=register input
        )
        port map (
            SRC_CLK  => '0',                -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            SRC_IN   => ASYNC_MASTER_RESET, -- 1-bit input: Input signal to be synchronized to dest_clk domain.
            DEST_CLK => XTAL_CLK_12MHz,     -- 1-bit input: Clock signal for the destination clock domain.
            DEST_OUT => MASTER_RESET        -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        );

    input_section_reset_cdc : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 1  -- DECIMAL; 0=do not register input, 1=register input
        )
        port map (
            SRC_CLK  => XTAL_CLK_12MHz,                        -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            SRC_IN   => current_state.cmd_input_section_reset, -- 1-bit input: Input signal to be synchronized to dest_clk domain.
            DEST_CLK => SAMPLE_CLK,                            -- 1-bit input: Clock signal for the destination clock domain.
            DEST_OUT => INPUT_SECTION_RESET                    -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        );

    asynchronous_fifo_reset_cdc : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 1  -- DECIMAL; 0=do not register input, 1=register input
        )
        port map (
            SRC_CLK  => XTAL_CLK_12MHz,                            -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            SRC_IN   => current_state.cmd_asynchronous_fifo_reset, -- 1-bit input: Input signal to be synchronized to dest_clk domain.
            DEST_CLK => SAMPLE_CLK,                                -- 1-bit input: Clock signal for the destination clock domain.
            DEST_OUT => ASYNCHRONOUS_FIFO_RESET                    -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        );

    output_section_reset_cdc : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 1  -- DECIMAL; 0=do not register input, 1=register input
        )
        port map (
            SRC_CLK  => XTAL_CLK_12MHz,                         -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            SRC_IN   => current_state.cmd_output_section_reset, -- 1-bit input: Input signal to be synchronized to dest_clk domain.
            DEST_CLK => TX_CLK_125_MHz,                         -- 1-bit input: Clock signal for the destination clock domain.
            DEST_OUT => OUTPUT_SECTION_RESET                    -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        );

end architecture arch;
