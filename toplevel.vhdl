
library ieee;
use ieee.std_logic_1164.all;

use work.types.all;
use work.constants.all;

-- TODO:
-- Make my own synchronous FIFO
-- Replace Xilinx FIFO synchronous fifo.
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

signal INPUT_SECTION_RESET     : std_logic; -- synchronous to SAMPLE_CLK
signal ASYNCHRONOUS_FIFO_RESET : std_logic; -- synchronous to SAMPLE_CLK
signal OUTPUT_SECTION_RESET    : std_logic; -- synchronous to TX_CLK_125_MHz

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

signal events_to_octets_input_ready : std_logic;

signal events_to_octets_data_out_to_frame_transmitter_data_in : std_logic_vector(7 downto 0);
signal events_to_octets_data_out_to_frame_transmitter_data_in_ready: std_logic;
signal events_to_octets_data_out_to_frame_transmitter_data_in_valid: std_logic;

signal frame_transmitter_data_out_to_octet_fifo_data_in : std_logic_vector(7 downto 0);
signal frame_transmitter_data_out_to_octet_fifo_data_in_ready : std_logic;
signal frame_transmitter_data_out_to_octet_fifo_data_in_valid : std_logic;

signal frame_transmitter_to_rgmii_transmitter_frame_metadata_octet_count : std_logic_vector(15 downto 0);
signal frame_transmitter_to_rgmii_transmitter_frame_metadata_checksum : std_logic_vector(15 downto 0);
signal frame_transmitter_to_rgmii_transmitter_frame_metadata_valid : std_logic;
signal frame_transmitter_to_rgmii_transmitter_frame_metadata_ready : std_logic;

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
            SAMPLE_CLK_SLOW => SAMPLE_CLK,
            SAMPLE_CLK_FAST => SAMPLE_CLK_FAST
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
            INPUT_SECTION_RESET     => INPUT_SECTION_RESET,
            ASYNCHRONOUS_FIFO_RESET => ASYNCHRONOUS_FIFO_RESET,
            OUTPUT_SECTION_RESET    => OUTPUT_SECTION_RESET
        );

    blink_pps : entity work.blink
        port map (
            CLK       => SAMPLE_CLK,
            RESET     => INPUT_SECTION_RESET,
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
                RESET   => INPUT_SECTION_RESET,
                INPUT   => IO_DIN(i),
                OUTPUT  => input_array(i)
            );
    end generate input_samplers;

    timestamper_instance : entity work.timestamper
        port map (
            CLK            => SAMPLE_CLK,
            RESET          => INPUT_SECTION_RESET,
            DATA_IN        => input_array,
            DATA_OUT       => timestamped_input_array,
            DATA_OUT_VALID => timestamped_input_array_valid
        );

    timestamped_input_array_filter_instance : entity work.timestamped_input_array_filter
        port map (
            CLK            => SAMPLE_CLK,
            RESET          => INPUT_SECTION_RESET,
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
            FIFO_IN_RESET       => ASYNCHRONOUS_FIFO_RESET,
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
            RESET          => OUTPUT_SECTION_RESET,
            DATA_IN        => asynchronous_fifo_data_out,
            DATA_IN_VALID  => asynchronous_fifo_data_out_valid,
            DATA_IN_READY  => event_processor_data_in_ready,
            DATA_OUT       => event_processor_output,
            DATA_OUT_VALID => event_processor_output_valid,
            DATA_OUT_READY => event_filter_input_ready
        );

    event_filter_instance : entity work.event_filter
        port map (
            CLK            => TX_CLK_125_MHz,
            RESET          => OUTPUT_SECTION_RESET,
            DATA_IN        => event_processor_output,
            DATA_IN_VALID  => event_processor_output_valid,
            DATA_IN_READY  => event_filter_input_ready,
            DATA_OUT       => event_filter_output,
            DATA_OUT_VALID => event_filter_output_valid,
            DATA_OUT_READY => events_to_octets_input_ready
        );
    
    events_to_octets_instance: entity work.events_to_octets
        port map (
            CLK   => TX_CLK_125_MHz,
            RESET => OUTPUT_SECTION_RESET,
            --
            DATA_IN       => event_filter_output,
            DATA_IN_VALID => event_filter_output_valid,
            DATA_IN_READY => events_to_octets_input_ready,
            --
            DATA_OUT        => events_to_octets_data_out_to_frame_transmitter_data_in,
            DATA_OUT_VALID  => events_to_octets_data_out_to_frame_transmitter_data_in_valid,
            DATA_OUT_READY  => events_to_octets_data_out_to_frame_transmitter_data_in_ready
        );

   frame_transmitter_instance: entity work.frame_transmitter
        port map (
            CLK             => TX_CLK_125_MHz,
            RESET           => OUTPUT_SECTION_RESET,
            --
            DATA_IN         => events_to_octets_data_out_to_frame_transmitter_data_in,
            DATA_IN_VALID   => events_to_octets_data_out_to_frame_transmitter_data_in_valid,
            DATA_IN_READY   => events_to_octets_data_out_to_frame_transmitter_data_in_ready,
            --
            DATA_OUT        => frame_transmitter_data_out_to_octet_fifo_data_in,
            DATA_OUT_VALID  => frame_transmitter_data_out_to_octet_fifo_data_in_valid,
            DATA_OUT_READY  => frame_transmitter_data_out_to_octet_fifo_data_in_ready,
            --
            FRAME_METADATA_OUT_OCTET_COUNT => frame_transmitter_to_rgmii_transmitter_frame_metadata_octet_count,
            FRAME_METADATA_OUT_CHECKSUM    => frame_transmitter_to_rgmii_transmitter_frame_metadata_checksum,
            FRAME_METADATA_OUT_VALID       => frame_transmitter_to_rgmii_transmitter_frame_metadata_valid,
            FRAME_METADATA_OUT_READY       => frame_transmitter_to_rgmii_transmitter_frame_metadata_ready
        );

    octet_fifo: entity work.synchronous_fifo
        port map (
            CLK   => TX_CLK_125_MHz,
            RESET => OUTPUT_SECTION_RESET,
            --
            FIFO_IN_DATA       => frame_transmitter_data_out_to_octet_fifo_data_in,
            FIFO_IN_DATA_VALID => frame_transmitter_data_out_to_octet_fifo_data_in_valid,
            FIFO_IN_DATA_READY => frame_transmitter_data_out_to_octet_fifo_data_in_ready,
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
            RESET                  => OUTPUT_SECTION_RESET,
            --
            ETH_TXCK               => IO_PHY_TXC,
            ETH_TXCTL              => IO_PHY_TXCTL,
            ETH_TXD                => IO_PHY_TXD,
            --
            MAC_ADDRESS_SRC        => x"0200c0a8007b", -- locally administered address: 02:00:c0:a8:00:7b
            --
         -- MAC_ADDRESS_DST        => x"04922658dd94", -- 04:92:26:58:dd:94 (win10)
         -- MAC_ADDRESS_DST        => x"a8a15993ebfe", -- a8:a1:59:93:eb:fe (hercules)
            MAC_ADDRESS_DST        => x"ffffffffffff", -- ff:ff:ff:ff:ff:ff (afmlab)
            --
         -- IP_ADDRESS_SRC         => x"c0a8007b",     -- 192.168.0.123
            IP_ADDRESS_SRC         => x"ac100064",     -- 172.16.0.100

         -- IP_ADDRESS_DST         => x"c0a800ff",     -- 192.168.0.255
         -- IP_ADDRESS_DST         => x"c0a80003",     -- 192.168.0.3 (win10)
            IP_ADDRESS_DST         => x"ac100001",     -- 172.16.0.1  (afmlab)
            --
            UDP_PORT_SRC           => x"2710", -- 10000 ; source UDP port
            UDP_PORT_DST           => x"2710", -- 10000 ; destination UDP port
            --
            DATA_IN       => synchronous_fifo_data_out,
            DATA_IN_VALID => synchronous_fifo_data_out_valid,
            DATA_IN_READY => rgmii_transmitter_data_in_ready,
            --
            FRAME_METADATA_IN_OCTET_COUNT => frame_transmitter_to_rgmii_transmitter_frame_metadata_octet_count,
            FRAME_METADATA_IN_CHECKSUM    => frame_transmitter_to_rgmii_transmitter_frame_metadata_checksum,
            FRAME_METADATA_IN_VALID       => frame_transmitter_to_rgmii_transmitter_frame_metadata_valid,
            FRAME_METADATA_IN_READY       => frame_transmitter_to_rgmii_transmitter_frame_metadata_ready
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
