
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity output_ddr is
    port (
        CLK     : in  std_logic;
        DPOS    : in  std_logic;
        DNEG    : in  std_logic;
        DDR_OUT : out std_logic
    );
end entity output_ddr;


architecture arch of output_ddr is
begin

    ODDR_instance : ODDR
        generic map(
            DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE" 
            INIT         => '0',         -- Initial value for Q port ('1' or '0')
            SRTYPE       => "SYNC"
        )
        port map (
            C  => CLK,     -- 1-bit clock input
            Q  => DDR_OUT, -- 1-bit DDR output
            CE => '1',     -- 1-bit clock enable input
            D1 => DPOS,    -- 1-bit data input (positive edge)
            D2 => DNEG,    -- 1-bit data input (negative edge)
            R  => '0',     -- 1-bit reset input
            S  => '0'      -- 1-bit set input
        );
  
end architecture arch;

