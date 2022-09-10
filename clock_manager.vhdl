library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

-- If you change the clock frequencies generated here, be sure to update the corresponding frequencies
-- in the "constants" package. 

entity clock_manager is
    port (
        XTAL_CLK_12MHz : in  std_logic; -- 12 MHz crystal clock on board.
        XTAL_CLK_10MHz : out std_logic; -- Imprecise 10 MHz clock generated from the 12 MHz XTAL clock (for testing).
        --
        IO_CLK_REFIN_10MHz : in  std_logic;
        --
        TX_CLK_125_MHz         : out std_logic;
        TX_CLK_125_MHz_SHIFTED : out std_logic;
        --
        SAMPLE_CLK_SLOW : out std_logic;
        SAMPLE_CLK_FAST : out std_logic
    );
end entity clock_manager;


architecture arch of clock_manager is

signal sig_feedback_1: std_logic;
signal sig_feedback_2: std_logic;
signal sig_feedback_3: std_logic;
signal sig_feedback_4: std_logic;

signal CLK_INTERMEDIATE_100MHz: std_logic;

begin

    -- We start at 12 MHz (XTAL_CLK).
    -- We multiply by 50 to arrive at 600 MHz, which is in the VCO range (600 .. 1200 MHz).
    -- We divide by 60.0 to arrive at the desired speed of 10 MHz.

   MMCME2_BASE_instance_1 : MMCME2_BASE
   generic map (
       BANDWIDTH        => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
       CLKFBOUT_MULT_F  => 50.0 ,        -- Multiply value for all CLKOUT (2.000-64.000).
       CLKFBOUT_PHASE   => 0.0,          -- Phase offset in degrees of CLKFB (-360.000-360.000).
       CLKIN1_PERIOD    => 83.333,       -- Input clock period in ns to ps resolution (i.e. 83.333 corresponds to 12 MHz).
       -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
       CLKOUT0_DIVIDE_F => 60.0,   -- Divide amount for CLKOUT0 (1.000-128.000).
       CLKOUT1_DIVIDE   => 1,
       CLKOUT2_DIVIDE   => 1,
       CLKOUT3_DIVIDE   => 1,
       CLKOUT4_DIVIDE   => 1,
       CLKOUT5_DIVIDE   => 1,
       CLKOUT6_DIVIDE   => 1,
       -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
       CLKOUT0_DUTY_CYCLE => 0.5,
       CLKOUT1_DUTY_CYCLE => 0.5,
       CLKOUT2_DUTY_CYCLE => 0.5,
       CLKOUT3_DUTY_CYCLE => 0.5,
       CLKOUT4_DUTY_CYCLE => 0.5,
       CLKOUT5_DUTY_CYCLE => 0.5,
       CLKOUT6_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
       CLKOUT0_PHASE => 0.0,
       CLKOUT1_PHASE => 0.0,
       CLKOUT2_PHASE => 0.0,
       CLKOUT3_PHASE => 0.0,
       CLKOUT4_PHASE => 0.0,
       CLKOUT5_PHASE => 0.0,
       CLKOUT6_PHASE => 0.0,
       CLKOUT4_CASCADE => false,   -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
       DIVCLK_DIVIDE   => 1,       -- Master division value (1-106)
       REF_JITTER1     => 0.0,     -- Reference input jitter in UI (0.000-0.999).
       STARTUP_WAIT    => true     -- Delays DONE until MMCM is locked (FALSE, TRUE)
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0   => XTAL_CLK_10MHz, -- 1-bit output: CLKOUT0
      CLKOUT0B  => open,           -- 1-bit output: Inverted CLKOUT0
      CLKOUT1   => open,           -- 1-bit output: CLKOUT1
      CLKOUT1B  => open,           -- 1-bit output: Inverted CLKOUT1
      CLKOUT2   => open,           -- 1-bit output: CLKOUT2
      CLKOUT2B  => open,           -- 1-bit output: Inverted CLKOUT2
      CLKOUT3   => open,           -- 1-bit output: CLKOUT3
      CLKOUT3B  => open,           -- 1-bit output: Inverted CLKOUT3
      CLKOUT4   => open,           -- 1-bit output: CLKOUT4
      CLKOUT5   => open,           -- 1-bit output: CLKOUT5
      CLKOUT6   => open,           -- 1-bit output: CLKOUT6
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT  => sig_feedback_1, -- 1-bit output: Feedback clock
      CLKFBOUTB => open,           -- 1-bit output: Inverted CLKFBOUT
      -- Status Ports: 1-bit (each) output: MMCM status ports
      LOCKED    => open,           -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock input
      CLKIN1    => XTAL_CLK_12MHz, -- 1-bit input: Clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      PWRDWN    => '0',            -- 1-bit input: Power-down
      RST       => '0',            -- 1-bit input: Reset
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN   => sig_feedback_1  -- 1-bit input: Feedback clock
   );

    -- We start at 10 MHz (IO_CLK_REFIN_10MHz).
    -- We multiply by 60 to arrive at 600 MHz, which is in the VCO range (600 .. 1200 MHz).
    -- We divide by 6 to arrive at the desired intermediate frequency of 100 MHz.

   MMCME2_BASE_instance_2 : MMCME2_BASE
   generic map (
       BANDWIDTH        => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
       CLKFBOUT_MULT_F  => 60.0 ,        -- Multiply value for all CLKOUT (2.000-64.000).
       CLKFBOUT_PHASE   => 0.0,          -- Phase offset in degrees of CLKFB (-360.000-360.000).
       CLKIN1_PERIOD    => 100.0,        -- Input clock period in ns to ps resolution (i.e. 100.0 corresponds to 10 MHz).
       -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
       CLKOUT0_DIVIDE_F => 6.0,          -- Divide amount for CLKOUT0 (1.000-128.000).
       CLKOUT1_DIVIDE   => 1,
       CLKOUT2_DIVIDE   => 1,
       CLKOUT3_DIVIDE   => 1,
       CLKOUT4_DIVIDE   => 1,
       CLKOUT5_DIVIDE   => 1,
       CLKOUT6_DIVIDE   => 1,
       -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
       CLKOUT0_DUTY_CYCLE => 0.5,
       CLKOUT1_DUTY_CYCLE => 0.5,
       CLKOUT2_DUTY_CYCLE => 0.5,
       CLKOUT3_DUTY_CYCLE => 0.5,
       CLKOUT4_DUTY_CYCLE => 0.5,
       CLKOUT5_DUTY_CYCLE => 0.5,
       CLKOUT6_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
       CLKOUT0_PHASE => 0.0,
       CLKOUT1_PHASE => 0.0,
       CLKOUT2_PHASE => 0.0,
       CLKOUT3_PHASE => 0.0,
       CLKOUT4_PHASE => 0.0,
       CLKOUT5_PHASE => 0.0,
       CLKOUT6_PHASE => 0.0,
       CLKOUT4_CASCADE => false,   -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
       DIVCLK_DIVIDE   => 1,       -- Master division value (1-106)
       REF_JITTER1     => 0.0,     -- Reference input jitter in UI (0.000-0.999).
       STARTUP_WAIT    => true     -- Delays DONE until MMCM is locked (FALSE, TRUE)
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0   => CLK_INTERMEDIATE_100MHz, -- 1-bit output: CLKOUT0
      CLKOUT0B  => open,                    -- 1-bit output: Inverted CLKOUT0
      CLKOUT1   => open,                    -- 1-bit output: CLKOUT1
      CLKOUT1B  => open,                    -- 1-bit output: Inverted CLKOUT1
      CLKOUT2   => open,                    -- 1-bit output: CLKOUT2
      CLKOUT2B  => open,                    -- 1-bit output: Inverted CLKOUT2
      CLKOUT3   => open,                    -- 1-bit output: CLKOUT3
      CLKOUT3B  => open,                    -- 1-bit output: Inverted CLKOUT3
      CLKOUT4   => open,                    -- 1-bit output: CLKOUT4
      CLKOUT5   => open,                    -- 1-bit output: CLKOUT5
      CLKOUT6   => open,                    -- 1-bit output: CLKOUT6
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT  => sig_feedback_2,          -- 1-bit output: Feedback clock
      CLKFBOUTB => open,                    -- 1-bit output: Inverted CLKFBOUT
      -- Status Ports: 1-bit (each) output: MMCM status ports
      LOCKED    => open,                    -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock input
      CLKIN1    => IO_CLK_REFIN_10MHz,      -- 1-bit input: Clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      PWRDWN    => '0',                     -- 1-bit input: Power-down
      RST       => '0',                     -- 1-bit input: Reset
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN   => sig_feedback_2           -- 1-bit input: Feedback clock
   );

   -- We start at 100 MHz (CLK_INTERMEDIATE_100MHz).
   -- We multiply by 10 to arrive at 1000 MHz, which is in the VCO range (600 .. 1200 MHz).
   -- We divide by 8 to arrive at the desired speed of 125 MHz.
   -- We divide by 2 to arrive at the desired speed of 500 MHz.

   MMCME2_BASE_instance_3 : MMCME2_BASE
   generic map (
       BANDWIDTH        => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
       CLKFBOUT_MULT_F  => 10.0,         -- Multiply value for all CLKOUT (2.000-64.000).
       CLKFBOUT_PHASE   => 0.0,          -- Phase offset in degrees of CLKFB (-360.000-360.000).
       CLKIN1_PERIOD    => 10.0,         -- Input clock period in ns to ps resolution (i.e. 10.0 corresponds to 100 MHz).
       -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
       CLKOUT0_DIVIDE_F => 1.0,          -- Divide amount for CLKOUT0 (1.000-128.000).
       CLKOUT1_DIVIDE   => 8,            -- TX_CLK_125_MHz
       CLKOUT2_DIVIDE   => 8,            -- TX_CLK_125_MHz_SHIFTED
       CLKOUT3_DIVIDE   => 8,            -- SAMPLE_CLK_SLOW
       CLKOUT4_DIVIDE   => 2,            -- SAMPLE_CLK_FAST
       CLKOUT5_DIVIDE   => 1,
       CLKOUT6_DIVIDE   => 1,
       -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
       CLKOUT0_DUTY_CYCLE => 0.5,
       CLKOUT1_DUTY_CYCLE => 0.5, -- TX_CLK_125_MHz
       CLKOUT2_DUTY_CYCLE => 0.5, -- TX_CLK_125_MHz_SHIFTED
       CLKOUT3_DUTY_CYCLE => 0.5, -- SAMPLE_CLK_SLOW
       CLKOUT4_DUTY_CYCLE => 0.5, -- SAMPLE_CLK_FAST
       CLKOUT5_DUTY_CYCLE => 0.5,
       CLKOUT6_DUTY_CYCLE => 0.5,
       -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
       CLKOUT0_PHASE   =>  0.0,
       CLKOUT1_PHASE   =>  0.0, -- TX_CLK_125_MHz
       CLKOUT2_PHASE   => 90.0, -- TX_CLK_125_MHz_SHIFTED
       CLKOUT3_PHASE   =>  0.0, -- SAMPLE_CLK_SLOW
       CLKOUT4_PHASE   =>  0.0, -- SAMPLE_CLK_FAST
       CLKOUT5_PHASE   =>  0.0,
       CLKOUT6_PHASE   =>  0.0,
       --
       CLKOUT4_CASCADE => false,   -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
       DIVCLK_DIVIDE   => 1,       -- Master division value (1-106)
       REF_JITTER1     => 0.0,     -- Reference input jitter in UI (0.000-0.999).
       STARTUP_WAIT    => true     -- Delays DONE until MMCM is locked (FALSE, TRUE)
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0   => open,                   -- 1-bit output: CLKOUT0
      CLKOUT0B  => open,                   -- 1-bit output: Inverted CLKOUT0
      CLKOUT1   => TX_CLK_125_MHz,         -- 1-bit output: CLKOUT1
      CLKOUT1B  => open,                   -- 1-bit output: Inverted CLKOUT1
      CLKOUT2   => TX_CLK_125_MHz_SHIFTED, -- 1-bit output: CLKOUT2
      CLKOUT2B  => open,                   -- 1-bit output: Inverted CLKOUT2
      CLKOUT3   => SAMPLE_CLK_SLOW,        -- 1-bit output: CLKOUT3
      CLKOUT3B  => open,                   -- 1-bit output: Inverted CLKOUT3
      CLKOUT4   => SAMPLE_CLK_FAST,        -- 1-bit output: CLKOUT4
      CLKOUT5   => open,                   -- 1-bit output: CLKOUT5
      CLKOUT6   => open,                   -- 1-bit output: CLKOUT6
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT  => sig_feedback_3,         -- 1-bit output: Feedback clock
      CLKFBOUTB => open,                   -- 1-bit output: Inverted CLKFBOUT
      -- Status Ports: 1-bit (each) output: MMCM status ports
      LOCKED    => open,                     -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock input
      CLKIN1    => CLK_INTERMEDIATE_100MHz,  -- 1-bit input: Clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      PWRDWN    => '0',                      -- 1-bit input: Power-down
      RST       => '0',                      -- 1-bit input: Reset
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN   => sig_feedback_3            -- 1-bit input: Feedback clock
   );

end architecture arch;
