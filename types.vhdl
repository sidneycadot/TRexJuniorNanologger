
library ieee;
use ieee.std_logic_1164.all;

use work.constants.all;

package types is

    type rgb_led_type is record
        r : std_logic;
        g : std_logic;
        b : std_logic;
    end record rgb_led_type;

    type pmod_type is record
        p1  : std_logic;
        p2  : std_logic;
        p3  : std_logic;
        p4  : std_logic;
        p7  : std_logic;
        p8  : std_logic;
        p9  : std_logic;
        p10 : std_logic;
    end record pmod_type;

    type aux_type is record
        p1 : std_logic;
        p2 : std_logic;
        p3 : std_logic;
    end record aux_type;

    type BitIndex is range 0 to SAMPLE_BITS_PER_CLOCK - 1;

    constant OLDEST_BIT   : BitIndex := BitIndex'low;
    constant YOUNGEST_BIT : BitIndex := BitIndex'high;

    type SampleBitVector is array(BitIndex) of std_logic;

    function sample_bit_vector_to_std_logic_vector(sample_bits: in SampleBitVector) return std_logic_vector;
    function std_logic_vector_to_sample_bit_vector(vec: in std_logic_vector(SAMPLE_BITS_PER_CLOCK - 1 downto 0)) return SampleBitVector;

    type InputArrayType is array(0 to NUM_INPUTS - 1) of SampleBitVector;

    type TimestampedInputArrayType is record
        timestamp : std_logic_vector(51 downto 0); -- 52 bits
        data      : InputArrayType;                -- 64 bits
    end record TimestampedInputArrayType;

    type FilteredTimestampedInputArrayType is record
        first     : std_logic;                     --  1 bit
        timestamp : std_logic_vector(51 downto 0); -- 52 bits
        data      : InputArrayType;                -- 64 bits
    end record FilteredTimestampedInputArrayType;

    type FilteredTimestampedOutputArrayType is record
        first     : std_logic;                               --  1 bit
        timestamp : std_logic_vector(54 downto 0);           -- 55 bits
        data      : std_logic_vector(NUM_INPUTS-1 downto 0); --  8 bits
    end record FilteredTimestampedOutputArrayType;

    function SelectBits(input_array: InputArrayType; index: in BitIndex) return std_logic_vector;
    function ExpandBitsToInputArray(most_recent_bits: std_logic_vector(NUM_INPUTS - 1 downto 0)) return InputArrayType;

end package types;


package body types is

    function sample_bit_vector_to_std_logic_vector(sample_bits: in SampleBitVector) return std_logic_vector is
    variable result: std_logic_vector(SAMPLE_BITS_PER_CLOCK - 1 downto 0);
    begin
        for i in 0 to SAMPLE_BITS_PER_CLOCK - 1 loop
            result(i) := sample_bits(BitIndex(i));
        end loop;
        return result;
    end function sample_bit_vector_to_std_logic_vector;

    function std_logic_vector_to_sample_bit_vector(vec: in std_logic_vector(SAMPLE_BITS_PER_CLOCK - 1 downto 0)) return SampleBitVector is
    variable result: SampleBitVector;
    begin
        for i in 0 to SAMPLE_BITS_PER_CLOCK - 1 loop
            result(BitIndex(i)) := vec(i);
        end loop;
        return result;
    end function std_logic_vector_to_sample_bit_vector;

    function SelectBits(input_array: InputArrayType; index: in BitIndex) return std_logic_vector is
    variable bits: std_logic_vector(NUM_INPUTS - 1 downto 0);
    begin
        for i in 0 to NUM_INPUTS - 1 loop
            bits(i) := input_array(i)(index);
        end loop;
        return bits;
    end function SelectBits;

    function ExpandBitsToInputArray(most_recent_bits: std_logic_vector(NUM_INPUTS - 1 downto 0)) return InputArrayType is
    variable input_array: InputArrayType;
    begin
        for i in 0 to NUM_INPUTS - 1 loop
            input_array(i) := (others => most_recent_bits(i));
        end loop;
        return input_array;
    end function ExpandBitsToInputArray;

end package body types;
