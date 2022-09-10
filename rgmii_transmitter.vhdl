library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity rgmii_transmitter is

    port (
        TX_CLK_125_MHz         : in  std_logic;
        TX_CLK_125_MHz_SHIFTED : in  std_logic;

        RESET : in std_logic;

        ETH_TXCK        : out std_logic;
        ETH_TXCTL       : out std_logic;
        ETH_TXD         : out std_logic_vector(3 downto 0);
        --
        MAC_ADDRESS_SRC : in std_logic_vector(47 downto 0);
        MAC_ADDRESS_DST : in std_logic_vector(47 downto 0);
        --
        IP_ADDRESS_SRC  : in std_logic_vector(31 downto 0);
        IP_ADDRESS_DST  : in std_logic_vector(31 downto 0);
        --
        UDP_PORT_SRC : in std_logic_vector(15 downto 0);
        UDP_PORT_DST : in std_logic_vector(15 downto 0);
        --
        DATA_IN        : in std_logic_vector(7 downto 0);
        DATA_IN_VALID  : in std_logic;
        DATA_IN_READY  : out std_logic;
        --
        PACKET_IN_BYTECOUNT : in  std_logic_vector(15 downto 0);
        PACKET_IN_CHECKSUM  : in  std_logic_vector(15 downto 0);
        PACKET_IN_VALID     : in  std_logic;
        PACKET_IN_READY     : out std_logic
        --    
    );

end entity rgmii_transmitter;


architecture arch of rgmii_transmitter is

    -- [22] Part 1: Fixed Ethernet header
    --
    --          0 ..  7  Ethernet preamble
    --          8 .. 13  MAC address destination                     -- start of CRC32.
    --         14 .. 19  MAC address source
    --         20 .. 21  Ethertype (0x0800 for IPv4)
    --
    -- [20] Part 2: IPv4 header
    --
    --         0        IPv4 / header length
    --         1        Miscellaneous (0)
    --         2..3     IP packet length
    --         4..5     IP packet identification
    --         6..7     IP fragmentation info (0)
    --         8        IP TTL (0x40)
    --         9        IP protocol (0x11: UDP)
    --         10..11   IP header checksum
    --         12..15   IPv4 destination address
    --         16..19   IPv4 source address
    --
    -- [8] Part 3: UDP header
    --
    --         0..1 UDP source port
    --         2..3 UDP destination port 
    --         4..5 UDP length
    --         6..7 UDP checksum
    --
    -- [8] Part 4: UDP payload; packet counter field.
    --
    --         0..7 UDP packet counter
    --
    -- [8*n] Part 5: UDP payload; event data array.
    --
    -- [npadding] Part 6: Ethernet padding
    --
    --      Total Ethernet payload: 20+8+8+(8*n)+npadding
    --       20+8+8+8*n+npadding == 46.
    --       npadding == max(0, 10-(8*n))
    --
    -- [4] Part 7: Frame Check Sum
    --
    -- 
    --
    -- [12] Part 8: Inter-Frame Gap
    --

    type FrameSequencerType is range 0 to 2047;

    type StateType is record
          -- Internal state.
          frame_sequencer      : FrameSequencerType;
          ip_identification    : std_logic_vector(15 downto 0);
          sequence_number      : std_logic_vector(63 downto 0);
          -- IP and UDP checksums
          ip_header_checksum   : std_logic_vector(15 downto 0);
          udp_checksum         : std_logic_vector(15 downto 0);
          -- CRC32 interface
          crc32                : std_logic_vector(31 downto 0);
          --
          r_data_in_ready      : std_logic;
          -- Output registers.
          --
          r_txctl              : std_logic;
          r_txd                : std_logic_vector(7 downto 0);
          --
          packet_in_ready      : std_logic;
          packet_in_bytecount  : std_logic_vector(15 downto 0);
          packet_in_checksum   : std_logic_vector(15 downto 0);
          --
          offset_events   : FrameSequencerType;
          offset_padding  : FrameSequencerType;
          offset_crc      : FrameSequencerType;
          offset_ifg      : FrameSequencerType;
          offset_ifg_end  : FrameSequencerType;
          offset_ifg_last : FrameSequencerType;
    end record StateType;

    constant reset_state : StateType := (
          frame_sequencer    => 0,
          ip_identification  => (others => '0'),
          sequence_number    => (others => '0'),
          ip_header_checksum => (others => '1'),
          udp_checksum       => (others => '1'),
          crc32              => (others => '0'),
          r_data_in_ready    => '1',
          r_txctl            => '0',
          r_txd              => "00000000",
          packet_in_ready    => '1',
          packet_in_bytecount => (others => '-'),
          packet_in_checksum  => (others => '-'),
          --
          offset_events    => 0,
          offset_padding   => 0,
          offset_crc       => 0,
          offset_ifg       => 0,
          offset_ifg_end   => 0,
          offset_ifg_last  => 0
      );

    function update_crc32(octet: in std_logic_vector(7 downto 0); old_crc32: in std_logic_vector(31 downto 0)) return std_logic_vector is
    variable new_crc32: std_logic_vector(31 downto 0);
    variable carry : std_logic;
    begin
        new_crc32 := old_crc32;
        for i in 0 to 7 loop
            carry := new_crc32(0);
            new_crc32 := '1' & new_crc32(31 downto 1);
            if carry = octet(i) then
                new_crc32 := new_crc32 xor x"edb88320";
            end if;
        end loop;
        return new_crc32;
    end function update_crc32;

    function ones_complement_subtract(a: in std_logic_vector(15 downto 0); b: in std_logic_vector(15 downto 0)) return std_logic_vector is
    -- Return (a - b) mod 65535, where 0 is represented as 0xffff.
    variable r:  std_logic_vector(15 downto 0);
    begin
        if b <= a then
            r := std_logic_vector(unsigned(a) - unsigned(b));
        else
            r := std_logic_vector(unsigned(a) + unsigned(not b));
        end if; 
        if r = x"0000" then
            r := x"ffff";
        end if;
        return r;
    end function ones_complement_subtract;

    function UpdateNextState(
            current_state       : in StateType;
            RESET               : in std_logic;
            MAC_ADDRESS_SRC     : in std_logic_vector(47 downto 0);
            MAC_ADDRESS_DST     : in std_logic_vector(47 downto 0);
            IP_ADDRESS_SRC      : in std_logic_vector(31 downto 0);
            IP_ADDRESS_DST      : in std_logic_vector(31 downto 0);
            UDP_PORT_SRC        : in std_logic_vector(15 downto 0);
            UDP_PORT_DST        : in std_logic_vector(15 downto 0);
            DATA_IN             : in std_logic_vector(7 downto 0);
            DATA_IN_VALID       : in std_logic;
            PACKET_IN_BYTECOUNT : in std_logic_vector(15 downto 0);
            PACKET_IN_CHECKSUM  : in std_logic_vector(15 downto 0);
            PACKET_IN_VALID     : in std_logic
        ) return StateType is

    variable state: StateType;

    variable v_udp_size         : std_logic_vector(15 downto 0);
    variable v_ip_size          : std_logic_vector(15 downto 0);

    variable proceed: boolean;

    begin
        -- Calculate next state based on current state and inputs.
        if RESET = '1' then
            -- Handle synchronous reset.
            state := reset_state;
        else
            -- Start from current state.
            state := current_state;

            if PACKET_IN_VALID = '1' and state.packet_in_ready = '1' then
                state.packet_in_bytecount := PACKET_IN_BYTECOUNT;
                state.packet_in_checksum  := PACKET_IN_CHECKSUM;
                state.packet_in_ready := '0';
                --
                state.offset_events   := 58;
                state.offset_padding  := FrameSequencerType(58 + to_integer(unsigned(state.packet_in_bytecount)));
                state.offset_crc      := maximum(state.offset_padding, 68);
                state.offset_ifg      := state.offset_crc + 4;
                state.offset_ifg_end  := state.offset_crc + 16;
                state.offset_ifg_last := state.offset_crc + 15;
            end if;

            v_udp_size := std_logic_vector(unsigned(state.packet_in_bytecount) + 16); --                  len(UDP header) + len(UDP payload).
            v_ip_size  := std_logic_vector(unsigned(state.packet_in_bytecount) + 36); -- len(IP header) + len(UDP header) + len(UDP payload)


            state.r_data_in_ready := '0';
            proceed := true;

            case state.frame_sequencer is

                when 0 =>
                    if state.packet_in_ready = '0' then
                        -- We have a valid packet specification.
                        state.r_txctl := '1'; state.r_txd := "01010101";
                    else
                        -- We're waiting for a packet specification ...
                        state.r_txctl := '0'; state.r_txd := "--------";
                        proceed := false;
                    end if;
                when 1 to  6  => state.r_txctl := '1'; state.r_txd := "01010101";
                when 7        => state.r_txctl := '1'; state.r_txd := "11010101";
                -- Ethernet destination MAC address
                when  8       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST(47 downto 40); -- Ethernet destination MAC address (MSB)
                when  9       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST(39 downto 32); -- Ethernet destination MAC address
                when 10       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST(31 downto 24); -- Ethernet destination MAC address
                when 11       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST(23 downto 16); -- Ethernet destination MAC address
                when 12       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST(15 downto  8); -- Ethernet destination MAC address
                when 13       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_DST( 7 downto  0); -- Ethernet destination MAC address (LSB)
                -- Ethernet source MAC address
                when 14       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC(47 downto 40); -- Ethernet sender MAC address (MSB)
                when 15       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC(39 downto 32); -- Ethernet sender MAC address
                when 16       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC(31 downto 24); -- Ethernet sender MAC address
                when 17       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC(23 downto 16); -- Ethernet sender MAC address
                when 18       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC(15 downto  8); -- Ethernet sender MAC address
                when 19       => state.r_txctl := '1'; state.r_txd := MAC_ADDRESS_SRC( 7 downto  0); -- Ethernet sender MAC address (LSB)
                -- Ethernet: packet type -- 0x0800 is IPv4
                when 20       => state.r_txctl := '1'; state.r_txd := x"08"; -- Ethertype (MSB)
                when 21       => state.r_txctl := '1'; state.r_txd := x"00"; -- Ethertype (LSB)
                -- IP: version and IHL (internet header length) in words
                when 22       => state.r_txctl := '1'; state.r_txd := x"45"; -- IPv4, header length = 5 32-bit words.
                -- IP: Differentiated Services Code Point (DSCP) and Explicit Congestion Notification (ECN)
                when 23       => state.r_txctl := '1'; state.r_txd := x"00";
                -- IP: Total IP packet length (IP header + IP data) -- 20 (IP header) + 8 (UDP header) + length(UDP payload). This excludes any padding.
                when 24       => state.r_txctl := '1'; state.r_txd := v_ip_size(15 downto 8); -- MSB
                when 25       => state.r_txctl := '1'; state.r_txd := v_ip_size( 7 downto 0); -- LSB
                -- IP: Identification
                when 26       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.ip_identification(15 downto 8)); -- MSB
                when 27       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.ip_identification( 7 downto 0)); -- LSB
                -- IP: Fragmentation info
                when 28       => state.r_txctl := '1'; state.r_txd := x"00"; -- MSB
                when 29       => state.r_txctl := '1'; state.r_txd := x"00"; -- LSB
                -- IP: Time-To-Live
                when 30       => state.r_txctl := '1'; state.r_txd := x"40"; -- TTL = 64
                -- IP: Protocol
                when 31       => state.r_txctl := '1'; state.r_txd := x"11"; -- Protocol = 0x11 (UDP)
                -- IP: Header checksum
                -- 0x4500 (meta)
                --        (ethernet payload length)
                -- seqnr  identification
                -- 0x4000 fragmentation
                -- 0x0000 (checksum)
                -- 0xc0a8 (source IP address)
                -- 0x00ea (source IP address)
                -- 0xc0a8 (destination IP address)
                -- 0xc0ff (destination IP address)
                when 32       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.ip_header_checksum(15 downto 8)); -- MSB
                when 33       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.ip_header_checksum( 7 downto 0)); -- LSB
                -- IP: Source address
                when 34       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_SRC(31 downto 24); -- 192.168.0.234
                when 35       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_SRC(23 downto 16);
                when 36       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_SRC(15 downto  8);
                when 37       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_SRC( 7 downto  0);
                -- IP: Destination address
                when 38       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_DST(31 downto 24); -- 192.168.0.255
                when 39       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_DST(23 downto 16);
                when 40       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_DST(15 downto  8);
                when 41       => state.r_txctl := '1'; state.r_txd := IP_ADDRESS_DST( 7 downto  0);
                -- UDP: Source port
                when 42       => state.r_txctl := '1'; state.r_txd := UDP_PORT_SRC(15 downto 8); -- MSB
                when 43       => state.r_txctl := '1'; state.r_txd := UDP_PORT_SRC( 7 downto 0); -- LSB
                -- UDP: Destination port
                when 44       => state.r_txctl := '1'; state.r_txd := UDP_PORT_DST(15 downto 8); -- MSB
                when 45       => state.r_txctl := '1'; state.r_txd := UDP_PORT_DST( 7 downto 0); -- LSB
                -- UDP: Length 26 == 8 (UDP header) + UDP payload
                when 46       => state.r_txctl := '1'; state.r_txd := v_udp_size(15 downto 8); -- MSB
                when 47       => state.r_txctl := '1'; state.r_txd := v_udp_size( 7 downto 0); -- LSB
                -- UDP: Checksum (zero if unused)
                when 48       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.udp_checksum(15 downto 8)); -- MSB
                when 49       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.udp_checksum( 7 downto 0)); -- LSB
                -- UDP: Payload -- 8 sequence bytes, followed by data bytes
                when 50       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(63 downto 56)); -- MSB
                when 51       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(55 downto 48));
                when 52       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(47 downto 40));
                when 53       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(39 downto 32));
                when 54       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(31 downto 24));
                when 55       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(23 downto 16));
                when 56       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number(15 downto  8));
                when 57       => state.r_txctl := '1'; state.r_txd := std_logic_vector(state.sequence_number( 7 downto  0)); -- LSB

                    if state.packet_in_bytecount /= x"0000" then
                        state.r_data_in_ready := '1';
                    end if;
 
                -- Rest of the packet.
                when others =>
                    -- data part
                    if (state.offset_events <= state.frame_sequencer) and (state.frame_sequencer < state.offset_padding) then
                        state.r_txctl := '1'; state.r_txd := DATA_IN;
                        -- if it's the last, we set r_data_in_ready to 0.
                        if state.frame_sequencer + 1 = state.offset_padding then
                            state.r_data_in_ready := '0';
                        else
                            state.r_data_in_ready := '1';
                        end if;
                    elsif (state.offset_padding <= state.frame_sequencer) and (state.frame_sequencer < state.offset_crc) then
                        -- padding part
                        state.r_txctl := '1'; state.r_txd := x"00";
                    elsif (state.frame_sequencer = state.offset_crc + 0) then
                        -- CRC32 checksum, first byte.
                        state.r_txctl := '1'; state.r_txd := state.crc32(7 downto 0);
                        -- Ethernet: Frame Checksum (CRC32), followed by nothing.
                    elsif (state.frame_sequencer = state.offset_crc + 1) then
                        -- CRC32 checksum, second byte.
                        state.r_txctl := '1'; state.r_txd := state.crc32(15 downto  8); 
                    elsif (state.frame_sequencer = state.offset_crc + 2) then
                        -- CRC32 checksum, third byte.
                        state.r_txctl := '1'; state.r_txd := state.crc32(23 downto 16); 
                    elsif (state.frame_sequencer = state.offset_crc + 3) then
                        -- CRC32 checksum, fourth byte.
                        state.r_txctl := '1'; state.r_txd := state.crc32(31 downto 24);
                    elsif (state.offset_ifg <= state.frame_sequencer) and (state.frame_sequencer < state.offset_ifg_end) then
                        -- Inter-Packet Gap (at least 12 octets)
                        state.r_txctl := '0'; state.r_txd := "--------";
                    end if;

            end case;

            if state.frame_sequencer = 8 then
                -- This is the first octet that needs to be CRC'ed.
                state.crc32 := update_crc32(state.r_txd, x"00000000");
            elsif (9 <= state.frame_sequencer) and (state.frame_sequencer < state.offset_crc) then
                state.crc32 := update_crc32(state.r_txd, state.crc32);
            end if;

           case state.frame_sequencer is
                when  0 => state.ip_header_checksum := ones_complement_subtract(x"ffff", x"4500");
                when  1 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, v_ip_size);
                when  2 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, state.ip_identification);
                when  3 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, x"0000");
                when  4 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, x"4011");
                when  5 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, IP_ADDRESS_SRC(31 downto 16));
                when  6 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, IP_ADDRESS_SRC(15 downto  0));
                when  7 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, IP_ADDRESS_DST(31 downto 16));
                when  8 => state.ip_header_checksum := ones_complement_subtract(state.ip_header_checksum, IP_ADDRESS_DST(15 downto  0));
                when others => null;
            end case;

           case state.frame_sequencer is
                when  0 => state.udp_checksum := ones_complement_subtract(x"ffff", x"0011");
                when  1 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, IP_ADDRESS_SRC(31 downto 16));
                when  2 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, IP_ADDRESS_SRC(15 downto  0));
                when  3 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, IP_ADDRESS_DST(31 downto 16));
                when  4 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, IP_ADDRESS_DST(15 downto  0));
                when  5 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, v_udp_size);
                when  6 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, v_udp_size);
                when  7 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, UDP_PORT_SRC);
                when  8 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, UDP_PORT_DST);
                when  9 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, state.sequence_number(63 downto 48));
                when 10 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, state.sequence_number(47 downto 32));
                when 11 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, state.sequence_number(31 downto 16));
                when 12 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, state.sequence_number(15 downto  0));
                when 13 => state.udp_checksum := ones_complement_subtract(state.udp_checksum, state.packet_in_checksum);
                when others => null;
            end case;

            -- Handle frame sequencer progression. 
            if proceed then
                if state.frame_sequencer = state.offset_ifg_last then
                    state.frame_sequencer   := 0;
                    state.ip_identification := std_logic_vector(unsigned(state.ip_identification) + 1);
                    state.sequence_number   := std_logic_vector(unsigned(state.sequence_number) + 1);
                    --
                    state.packet_in_ready   := '1';
                else
                    state.frame_sequencer := state.frame_sequencer + 1;
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
            MAC_ADDRESS_SRC,
            MAC_ADDRESS_DST,
            IP_ADDRESS_SRC,
            IP_ADDRESS_DST,
            UDP_PORT_SRC,
            UDP_PORT_DST,
            DATA_IN,
            DATA_IN_VALID,
            PACKET_IN_BYTECOUNT,
            PACKET_IN_CHECKSUM,
            PACKET_IN_VALID
        );

    current_state <= next_state when rising_edge(TX_CLK_125_MHz);

    DATA_IN_READY   <= current_state.r_data_in_ready;
    PACKET_IN_READY <= current_state.packet_in_ready;

    -- Instantiate ODDR instances for TX clock, TX control, and 4 TX data bits.

    output_ddr_TXC: entity work.output_ddr
        port map (
            CLK     => TX_CLK_125_MHz_SHIFTED,
            DPOS    => '1',
            DNEG    => '0',
            DDR_OUT => ETH_TXCK
        );

    output_ddr_TXCTL: entity work.output_ddr
        port map (
            CLK     => TX_CLK_125_MHz,
            DPOS    => current_state.r_txctl,
            DNEG    => current_state.r_txctl,
            DDR_OUT => ETH_TXCTL
        );

    output_ddr_TXD_gen: for i in 0 to 3 generate
        output_ddr_TXD: entity work.output_ddr
            port map (
                CLK     => TX_CLK_125_MHz,
                DPOS    => current_state.r_txd(i + 0),
                DNEG    => current_state.r_txd(i + 4),
                DDR_OUT => ETH_TXD(i)
            );
    end generate output_ddr_TXD_gen;

end architecture arch;
