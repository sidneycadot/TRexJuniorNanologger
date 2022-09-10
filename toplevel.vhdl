
library ieee;
use ieee.std_logic_1164.all;

use work.types.all;
use work.constants.all;

-- TODO:
-- Make my own synchronous FIFO
-- Replace Xilinx FIFO.
--
entity toplevel is
    port (
        XTAL_CLK_12MHz     : in std_logic; -- Input clock (12 MHz)
        IO_CLK_REFIN_10MHz : in std_logic; -- Input clock (10 MHz)
        --
        LED0     : out rgb_led_type;
        LED1     : out std_logic;
        LED2     : out std_logic;
        --
        BUTTON1  : in  std_logic;
        BUTTON2  : in  std_logic;
        --
        IO_DIN   : in  std_logic_vector(7 downto 0); -- 8x BNC inputs.
        IO_DOUT  : out std_logic_vector(7 downto 0); -- 8x BNC outputs.
        --
        UART_RX  : in  std_logic;
        UART_TX  : out std_logic;
        --
        IO_PHY_RESET_N : out std_logic;
        --
        IO_PHY_MDIO_CLOCK : out   std_logic;
        IO_PHY_MDIO_DATA  : inout std_logic;
        --
        IO_PHY_TXC   : out std_logic;
        IO_PHY_TXCTL : out std_logic;
        IO_PHY_TXD   : out std_logic_vector(3 downto 0);
        --
        PMOD     : out pmod_type; -- PMOD connector on the CMOD-A7 module.
        IO_PMOD  : out pmod_type; -- PMOD connector on the CMOD IO board.
        IO_AUX   : in aux_type    -- AUX pin header on the CMOD IO board.
        --
    );
end entity toplevel;


architecture arch of toplevel is

------------------------------------------------------ Clock signals

signal XTAL_CLK_10MHz         : std_logic;
signal TX_CLK_125_MHz         : std_logic;
signal TX_CLK_125_MHz_SHIFTED : std_logic;

signal SAMPLE_CLK      : std_logic;
signal SAMPLE_CLK_FAST : std_logic;

------------------------------------------------------ Reset signals

signal ASYNC_MASTER_RESET : std_logic;

signal PPS_RESET              : std_logic; -- synchronous to SAMPLE_CLK
signal SAMPLER_RESET          : std_logic; -- synchronous to SAMPLE_CLK
signal TIMESTAMPER_RESET      : std_logic; -- synchronous to SAMPLE_CLK
signal INPUT_FILTER_RESET     : std_logic; -- synchronous to SAMPLE_CLK
signal ASYNC_FIFO_RESET       : std_logic; -- synchronous to SAMPLE_CLK
signal EVENT_PROCESSOR_RESET  : std_logic; -- synchronous to TX_CLK_125_MHz
signal EVENT_FILTER_RESET     : std_logic; -- synchronous to TX_CLK_125_MHz
signal EVENTS_TO_OCTETS_RESET : std_logic; -- synchronous to TX_CLK_125_MHz
signal SYNC_FIFO_RESET        : std_logic; -- synchronous to TX_CLK_125_MHz
signal ETH_TX_RESET           : std_logic; -- synchronous to TX_CLK_125_MHz

------------------------------------------------------ Data pipeline signals

signal input_array : InputArrayType;

signal timestamped_input_array : TimestampedInputArrayType;
signal timestamped_input_array_valid : std_logic;

signal filtered_timestamped_input_array : FilteredTimestampedInputArrayType;
signal filtered_timestamped_input_array_valid : std_logic;

signal asynchronous_fifo_data_in_ready : std_logic;

signal asynchronous_fifo_data_out       : FilteredTimestampedInputArrayType;
signal asynchronous_fifo_data_out_valid : std_logic;

signal event_processor_data_in_ready : std_logic;
signal event_processor_output : FilteredTimestampedOutputArrayType;
signal event_processor_output_valid : std_logic;

signal event_filter_input_ready : std_logic;
signal event_filter_output : FilteredTimestampedOutputArrayType;
signal event_filter_output_valid : std_logic;

signal event_counter_data_in_ready : std_logic;
signal event_counter_output        : FilteredTimestampedOutputArrayType;
signal event_counter_output_valid  : std_logic;

signal packet_bytecount : std_logic_vector(15 downto 0);
signal packet_checksum  : std_logic_vector(15 downto 0);
signal packet_valid     : std_logic;
signal packet_ready     : std_logic;

signal events_to_octets_input_ready : std_logic;
signal events_to_octets_data_out : std_logic_vector(7 downto 0);
signal events_to_octets_data_out_valid : std_logic;

signal event_word : std_logic_vector(63 downto 0);
signal event_word_swapped : std_logic_vector(63 downto 0);

signal synchronous_fifo_data_in_ready  : std_logic;
signal synchronous_fifo_data_out       : std_logic_vector(7 downto 0);
signal synchronous_fifo_data_out_valid : std_logic;

signal rgmii_transmitter_data_in_ready : std_logic;

------------------------------------------------------ Miscellaneous signals

signal pps: std_logic;

begin

    clock_manager_instance : entity work.clock_manager
        port map (
            XTAL_CLK_12MHz => XTAL_CLK_12MHz, -- Input clock
            XTAL_CLK_10MHz => XTAL_CLK_10MHz, -- Output clock derived from XTAL_CLK_12MHz.
            --
            IO_CLK_REFIN_10MHz => IO_CLK_REFIN_10MHz, -- Input clock
            --
            TX_CLK_125_MHz         => TX_CLK_125_MHz,
            TX_CLK_125_MHz_SHIFTED => TX_CLK_125_MHz_SHIFTED,
            --
            SAMPLE_CLK_SLOW          => SAMPLE_CLK,
            SAMPLE_CLK_FAST          => SAMPLE_CLK_FAST
        );

    ASYNC_MASTER_RESET <= BUTTON1 or BUTTON2;

    reset_manager_instance : entity work.reset_manager
        port map (
            XTAL_CLK_12MHz => XTAL_CLK_12MHz,
            SAMPLE_CLK     => SAMPLE_CLK, 
            TX_CLK_125_MHz => TX_CLK_125_MHz,
            --
            ASYNC_MASTER_RESET => ASYNC_MASTER_RESET,
            --
            PPS_RESET              => PPS_RESET,
            SAMPLER_RESET          => SAMPLER_RESET,
            TIMESTAMPER_RESET      => TIMESTAMPER_RESET,
            INPUT_FILTER_RESET     => INPUT_FILTER_RESET,
            ASYNC_FIFO_RESET       => ASYNC_FIFO_RESET,
            EVENT_PROCESSOR_RESET  => EVENT_PROCESSOR_RESET,
            EVENT_FILTER_RESET     => EVENT_FILTER_RESET,
            EVENTS_TO_OCTETS_RESET => EVENTS_TO_OCTETS_RESET,
            SYNC_FIFO_RESET        => SYNC_FIFO_RESET,
            ETH_TX_RESET           => ETH_TX_RESET
        );

    blink_pps : entity work.blink
        port map (
            CLK       => SAMPLE_CLK,
            RESET     => PPS_RESET,
            BLINK_OUT => pps
        );

    ------------------------------------------------------
    --
    -- Start of the primary signal processing chain
    --
    ------------------------------------------------------

    input_samplers: for i in 0 to NUM_INPUTS - 1 generate
        input_sampler_instance : entity work.input_sampler
            port map (
                --
                SAMPLE_CLK      => SAMPLE_CLK,
                SAMPLE_CLK_FAST => SAMPLE_CLK_FAST,
                --
                RESET   => SAMPLER_RESET,
                INPUT   => IO_DIN(i),
                OUTPUT  => input_array(i)
            );
    end generate input_samplers;

    timestamper_instance : entity work.timestamper
        port map (
            CLK            => SAMPLE_CLK,
            RESET          => TIMESTAMPER_RESET,
            DATA_IN        => input_array,
            DATA_OUT       => timestamped_input_array,
            DATA_OUT_VALID => timestamped_input_array_valid
        );

    timestamped_input_array_filter_instance : entity work.timestamped_input_array_filter
        port map (
            CLK            => SAMPLE_CLK,
            RESET          => INPUT_FILTER_RESET,
            DATA_IN        => timestamped_input_array,
            DATA_IN_VALID  => timestamped_input_array_valid,
            DATA_OUT       => filtered_timestamped_input_array,
            DATA_OUT_VALID => filtered_timestamped_input_array_valid,
            DATA_OUT_READY => asynchronous_fifo_data_in_ready
        );

    asynchronous_fifo_instance: entity work.asynchronous_fifo
        port map (
            --
            FIFO_IN_CLK         => SAMPLE_CLK,
            FIFO_IN_RESET       => ASYNC_FIFO_RESET,
            FIFO_IN_DATA        => filtered_timestamped_input_array,
            FIFO_IN_DATA_VALID  => filtered_timestamped_input_array_valid,
            FIFO_IN_DATA_READY  => asynchronous_fifo_data_in_ready,
            --
            FIFO_OUT_CLK        => TX_CLK_125_MHz,
            FIFO_OUT_DATA       => asynchronous_fifo_data_out,
            FIFO_OUT_DATA_VALID => asynchronous_fifo_data_out_valid,
            FIFO_OUT_DATA_READY => event_processor_data_in_ready
        );

    event_processor_instance : entity work.event_processor
        port map (
            CLK            => TX_CLK_125_MHz,
            RESET          => EVENT_PROCESSOR_RESET,
            DATA_IN        => asynchronous_fifo_data_out,
            DATA_IN_VALID  => asynchronous_fifo_data_out_valid,
            DATA_IN_READY  => event_processor_data_in_ready,
            DATA_OUT       => event_processor_output,
            DATA_OUT_VALID => event_processor_output_valid,
            DATA_OUT_READY => event_filter_input_ready
        );

    event_filter_instance: entity work.event_filter
        port map (
            CLK            => TX_CLK_125_MHz,
            RESET          => EVENT_FILTER_RESET,
            DATA_IN        => event_processor_output,
            DATA_IN_VALID  => event_processor_output_valid,
            DATA_IN_READY  => event_filter_input_ready,
            DATA_OUT       => event_filter_output,
            DATA_OUT_VALID => event_filter_output_valid,
            DATA_OUT_READY => event_counter_data_in_ready
        );

    event_counter_instance: entity work.event_counter
        port map (
            CLK             => TX_CLK_125_MHz,
            RESET           => EVENT_FILTER_RESET,
            --
            DATA_IN         => event_filter_output,
            DATA_IN_VALID   => event_filter_output_valid,
            DATA_IN_READY   => event_counter_data_in_ready,
            --
            DATA_OUT        => event_counter_output,
            DATA_OUT_VALID  => event_counter_output_valid,
            DATA_OUT_READY  => synchronous_fifo_data_in_ready,
            --
            PACKET_OUT_BYTECOUNT => packet_bytecount,
            PACKET_OUT_CHECKSUM  => packet_checksum,
            PACKET_OUT_VALID     => packet_valid,
            PACKET_OUT_READY     => packet_ready
        );

    --events_to_octets_instance: entity work.events_to_octets
    --    port map (
    --        CLK   => TX_CLK_125_MHz,
    --        RESET => EVENTS_TO_OCTETS_RESET,
    --        --
    --        DATA_IN       => event_filter_output,
    --        DATA_IN_VALID => event_filter_output_valid,
    --        DATA_IN_READY => events_to_octets_input_ready,
    --        --
    --        DATA_OUT        => events_to_octets_data_out,
    --        DATA_OUT_VALID  => events_to_octets_data_out_valid,
    --        DATA_OUT_READY  => synchronous_fifo_data_in_ready
    --    );
    
    event_word <= event_filter_output.first & event_filter_output.timestamp & event_filter_output.data;
    event_word_swapped <= event_word( 7 downto  0) & event_word(15 downto  8) & event_word(23 downto 16) & event_word(31 downto 24) &
                          event_word(39 downto 32) & event_word(47 downto 40) & event_word(55 downto 48) & event_word(63 downto 56);

    synchronous_fifo_instance: entity work.synchronous_fifo
        port map (
            CLK   => TX_CLK_125_MHz,
            RESET => SYNC_FIFO_RESET,
            --
            FIFO_IN_DATA       => event_word_swapped,
            FIFO_IN_DATA_VALID => event_filter_output_valid,
            FIFO_IN_DATA_READY => synchronous_fifo_data_in_ready,
            --
            FIFO_OUT_DATA       => synchronous_fifo_data_out,
            FIFO_OUT_DATA_VALID => synchronous_fifo_data_out_valid,
            FIFO_OUT_DATA_READY => rgmii_transmitter_data_in_ready
        );

    rgmii_transmitter_instance : entity work.rgmii_transmitter
        port map (
            TX_CLK_125_MHz         => TX_CLK_125_MHz,
            TX_CLK_125_MHz_SHIFTED => TX_CLK_125_MHz_SHIFTED,
            --
            RESET                  => ETH_TX_RESET,
            --
            ETH_TXCK               => IO_PHY_TXC,
            ETH_TXCTL              => IO_PHY_TXCTL,
            ETH_TXD                => IO_PHY_TXD,
            --
            MAC_ADDRESS_SRC        => x"0200c0a8007b", -- locally administered address: 02:00:c0:a8:00:7b
         -- MAC_ADDRESS_DST        => x"ffffffffffff", -- ff:ff:ff:ff:ff:ff
            MAC_ADDRESS_DST        => x"04922658dd94", -- 04:92:26:58:dd:94 (win10)
         -- MAC_ADDRESS_DST        => x"a8a15993ebfe", -- a8:a1:59:93:eb:fe (hercules)
            --
            IP_ADDRESS_SRC         => x"c0a8007b",     -- 192.168.0.123
         -- IP_ADDRESS_DST         => x"c0a800ff",     -- 192.168.0.255
            IP_ADDRESS_DST         => x"c0a80003",     -- 192.168.0.3 (win10)
         -- IP_ADDRESS_DST         => x"c0a8",     -- 192.168.0.2 (hercules)
            --
            UDP_PORT_SRC           => x"2710", -- 10000
            UDP_PORT_DST           => x"2710", -- 10000
            --
            DATA_IN       => synchronous_fifo_data_out,
            DATA_IN_VALID => synchronous_fifo_data_out_valid,
            DATA_IN_READY => rgmii_transmitter_data_in_ready,
            --
            PACKET_IN_BYTECOUNT => packet_bytecount,
            PACKET_IN_CHECKSUM  => packet_checksum,
            PACKET_IN_VALID     => packet_valid,
            PACKET_IN_READY     => packet_ready
        );

    IO_PHY_RESET_N    <= '1';
    IO_PHY_MDIO_CLOCK <= '0';
    IO_PHY_MDIO_DATA  <= '0';

    LED0.r <= not pps;
    LED0.g <= not pps;
    LED0.b <= not pps;

    LED1 <= not (IO_AUX.p1 and IO_AUX.p2 and IO_AUX.p3);
    LED2 <= not (IO_AUX.p1 and IO_AUX.p2 and IO_AUX.p3);

    IO_DOUT <= XTAL_CLK_10MHz & pps & "000000";

    UART_TX <= UART_RX; -- Loop-back input to output.

    PMOD    <= (others => '0');
    IO_PMOD <= (others => '0');

end architecture arch;
