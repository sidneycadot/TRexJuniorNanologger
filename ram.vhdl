
library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

entity ram is
    port (
        CLK : in std_logic;
        --
        MEM_READ_ADDRESS : in  std_logic_vector(11 downto 0);
        MEM_READ_DATA    : out std_logic_vector(7 downto 0);
        MEM_READ_ENABLE  : in  std_logic;
        --
        MEM_WRITE_ADDRESS : in std_logic_vector(11 downto 0);
        MEM_WRITE_DATA    : in std_logic_vector(7 downto 0);
        MEM_WRITE_ENABLE  : in std_logic
    );
end entity ram;


architecture arch of ram is

    type AddressType is range 0 to 4095;

    type RAMType is array (AddressType) of std_logic_vector(7 downto 0);

    type StateType is record
            ram           : RAMType;
            mem_read_data : std_logic_vector(7 downto 0);
        end record StateType;

    constant reset_state : StateType := (
            ram           => (others => (others => '0')),
            mem_read_data => (others => '0')
        );

    function UpdateNextState(
            current_state     : in StateType;
            MEM_READ_ADDRESS  : in std_logic_vector(11 downto 0);
            MEM_READ_ENABLE   : in std_logic;
            MEM_WRITE_ADDRESS : in std_logic_vector(11 downto 0);
            MEM_WRITE_DATA    : in std_logic_vector(7 downto 0);
            MEM_WRITE_ENABLE  : in std_logic
        ) return StateType is

    variable state : StateType;

    begin

        state := current_state;

        if MEM_READ_ENABLE = '1' then
            state.mem_read_data := state.ram(AddressType(to_integer(unsigned(MEM_READ_ADDRESS))));
        end if;

        if MEM_WRITE_ENABLE = '1' then
            state.ram(AddressType(to_integer(unsigned(MEM_WRITE_ADDRESS)))) := MEM_WRITE_DATA;
        end if;

        return state;

    end function UpdateNextState;

signal current_state: StateType := reset_state;
signal next_state: StateType;

begin

    next_state <= UpdateNextState(current_state, MEM_READ_ADDRESS, MEM_READ_ENABLE, MEM_WRITE_ADDRESS, MEM_WRITE_DATA, MEM_WRITE_ENABLE);

    current_state <= next_state when rising_edge(CLK);

    MEM_READ_DATA <= current_state.mem_read_data;

end architecture arch;
