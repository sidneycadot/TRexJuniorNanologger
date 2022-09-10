
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.constants.all;
use work.types.all;

entity input_sampler is
    port (
        SAMPLE_CLK      : in std_logic;
        SAMPLE_CLK_FAST : in std_logic;
        --
        RESET  : in  std_logic;
        INPUT  : in  std_logic;
        OUTPUT : out SampleBitVector
    );
end entity input_sampler;


architecture arch of input_sampler is

begin

    ISERDESE2_instance : ISERDESE2
        generic map (
            --
            DATA_RATE         => "DDR",                 -- [ok] DDR, SDR
            DATA_WIDTH        => SAMPLE_BITS_PER_CLOCK, -- [ok] Parallel data width (2-8, 10, 14)
            DYN_CLKDIV_INV_EN => "FALSE",               -- [ok] Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
            DYN_CLK_INV_EN    => "FALSE",               -- [ok] Enable DYNCLKINVSEL inversion (FALSE, TRUE)
            --
            INTERFACE_TYPE    => "NETWORKING",          -- [ok] MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
            IOBDELAY          => "NONE",                -- [ok] NONE, BOTH, IBUF, IFD
            NUM_CE            => 1,                     -- [ok] Number of clock enables (1, 2)
            OFB_USED          => "FALSE",               -- [ok] Select OFB path (FALSE, TRUE)
            SERDES_MODE       => "MASTER",              -- [ok] MASTER, SLAVE
            --
            INIT_Q1  => '0',                            -- [  ] INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
            INIT_Q2  => '0',
            INIT_Q3  => '0',
            INIT_Q4  => '0',
            --
            SRVAL_Q1 => '0',                            -- [  ] SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
            SRVAL_Q2 => '0',
            SRVAL_Q3 => '0',
            SRVAL_Q4 => '0'
        )
        port map (
            O  => open,                                 -- [ok] 1-bit output: Combinatorial output
            --
            -- Q1 - Q8: 1-bit (each) output: Registered data outputs
            --
            Q1 => OUTPUT(7), -- youngest bit            -- [ok]
            Q2 => OUTPUT(6),                            -- [ok]
            Q3 => OUTPUT(5),                            -- [ok]
            Q4 => OUTPUT(4),                            -- [ok]
            Q5 => OUTPUT(3),                            -- [ok]
            Q6 => OUTPUT(2),                            -- [ok]
            Q7 => OUTPUT(1),                            -- [ok]
            Q8 => OUTPUT(0), -- oldest bit              -- [ok]
            --
            -- SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
            --
            SHIFTOUT1 => open,                          -- [ok]
            SHIFTOUT2 => open,                          -- [ok]
            --
            BITSLIP   => '0',                           -- [ok] 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to CLKDIV when asserted (active High).
                                                        --      Subsequently, the data seen on the Q1 to Q8 output ports will shift, as in a barrel-shifter operation,
                                                        --      one position every time Bitslip is invoked (DDR operation is different from SDR).
            --
            -- CE1, CE2: 1-bit (each) input: Data register clock enable inputs
            --
            CE1     => '1',                    -- [ok]
            CE2     => '0',                    -- [ok]
            --
            -- Clocks: 1-bit (each) input: ISERDESE2 clock input ports
            --
            CLK     =>     SAMPLE_CLK_FAST,    -- [ok] 1-bit input: High-speed clock
            CLKB    => not SAMPLE_CLK_FAST,    -- [ok] 1-bit input: High-speed secondary clock
            CLKDIV  =>     SAMPLE_CLK,         -- [ok] 1-bit input: Divided clock
            --
            CLKDIVP => '0' ,                   -- [ok] 1-bit input: (unused)
            OCLK    => '0' ,                   -- [ok] 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY" 
            OCLKB   => '0' ,                   -- [ok] 1-bit input: High speed negative edge output clock
            --
            RST   => RESET,                    -- [ok] 1-bit input: Active high asynchronous reset
            --
            -- Input Data: 1-bit (each) input: ISERDESE2 data input ports
            --
            D     => INPUT,                    -- [ok] 1-bit input: Data input
            DDLY  => '0',                      -- [ok] 1-bit input: Serial data from IDELAYE2 (unused)
            OFB   => '0',                      -- [ok] 1-bit input: Data feedback from OSERDESE2 (unused)
            --
            -- Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
            --
            DYNCLKDIVSEL => '0',               -- [ok] 1-bit input: Dynamic CLKDIV inversion
            DYNCLKSEL    => '0',               -- [ok] 1-bit input: Dynamic CLK/CLKB inversion
            --
            -- SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
            --
            SHIFTIN1 => '0',                   -- [ok]
            SHIFTIN2 => '0'                    -- [ok]
        );

end architecture arch;
