
######################################################################
#                                                                    #
#  Master Xilinx Device Constraints (XDC) file for the T-Rex Junior  #
#                                                                    #
######################################################################

# This file is based on the Master XDC file for the CMOD-A7 rev. B.
# The FPGA on the Digilent CMOD-A7 board is a XC7A35TCPG236-1.

# Set configuration voltages.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Configuration sizes:
#
# "Both the Artix-7 35T and 15T bitstreams are typically 17,536,096 bits." (2,192,012 bytes).
#
# This is indeed the size of a BIN file. A BIT file has a small header prepended (~ 120 bytes).
#
# If BITSTREAM.GENERAL.COMPRESS is set to TRUE, the bit/bin files are smaller by about a factor 3 (~ 750 kbytes).

# Enable bitstream compression.
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# set_property BITSTREAM.CONFIG.CONFIGRATE 33
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4
# set_property BITSTREAM.CONFIG.SPI_FALL_EDGE {YES / NO}

#########################################################################################
#                                                                                       #
#  Set properties for FPGA pins that connect to resources on the CMOD-A7 module itself  #
#                                                                                       #
#########################################################################################

# 12 MHz XTAL clock.
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports XTAL_CLK_12MHz]

# RGB LED (outputs; 0=ON, 1=OFF)
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {LED0[r]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {LED0[g]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {LED0[b]}]

# Green LEDs (outputs; 0=OFF, 1=ON)
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports LED1]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports LED2]

# Buttons (inputs; 0=NOT PRESSED, 1=PRESSED)
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports BUTTON1]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports BUTTON2]

# UART (TX is output to USB, RX is input from USB)
# FTDI FT2232HQ USB-UART bridge
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports UART_TX]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports UART_RX]

# CMOD-A7 module PMOD header (can be used as input or output)
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {PMOD[p1]}]
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS33} [get_ports {PMOD[p2]}]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports {PMOD[p3]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {PMOD[p4]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {PMOD[p7]}]
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports {PMOD[p8]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports {PMOD[p9]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {PMOD[p10]}]

# Crypto 1 Wire Interface
# This chip is not documented. There's place for it on the PCB, but it isn't populated during manufacturing.
# See https://forum.digilentinc.com/topic/19107-cmod-a7-sha204/
#
# set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports { crypto_sda }]; # IO_0_14 Sch=crypto_sda

# QSPI - 32 MB flash controller.
#
# "In manufacturing, parts sometimes need to be replaced when the product goes end-of-life.
#  The Quad SPI Flash memory on any particular Cmod A7 may be one of the drop-in replacements found in the Table 4.1 below.
#  To determine which part is used by a particular board, look at the part number printed on IC3 on the bottom of the Cmod A7 (See Figure 4.2).
#  Datasheets for each flash part can be found on their respective manufacurer's website."
#
#   Micron N25Q032A                         -- n25q32-3.3v-spi-x1_x2_x4
#   Macronix MX25L3233FZBI-08G/Q            -- mx25l3233f-spi-x1_x2_x4
#
# My two models:
#
#   Serial nr 1: 210328AFE34CA / iSerial: 210328AFE34C (blue enclosure) -- mx25l3233f-spi-x1_x2_x4
#   Serial nr 2: 210328AFE321A / iSerial: 210328AFE321 (red enclosure)  -- mx25l3233f-spi-x1_x2_x4

#set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports QSPI_CS]
#set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports QSPI_CLK]
#set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {QSPI_DQ[0]}]
#set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {QSPI_DQ[1]}]
#set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {QSPI_DQ[2]}]
#set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {QSPI_DQ[3]}]

# 512 KB Static RAM (SRAM):
# An ISSI IS61WV5128BLL-10BLI chip.

#set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[0]}]
#set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[1]}]
#set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[2]}]
#set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[3]}]
#set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[4]}]
#set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[5]}]
#set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[6]}]
#set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[7]}]
#set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[8]}]
#set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[9]}]
#set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[10]}]
#set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[11]}]
#set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[12]}]
#set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[13]}]
#set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[14]}]
#set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[15]}]
#set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[16]}]
#set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[17]}]
#set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {SRAM_ADDR[18]}]
#set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[0]}]
#set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[1]}]
#set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[2]}]
#set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[3]}]
#set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[4]}]
#set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[5]}]
#set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[6]}]
#set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {SRAM_DATA[7]}]
#set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports SRAM_OEn]
#set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports SRAM_WEn]
#set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS33} [get_ports SRAM_CEn]

################################################################################################################
#                                                                                                              #
#  Set properties for FPGA pins that connect to resources on the CMOD-A7 I/O board via the 48-pins DIP socket  #
#                                                                                                              #
################################################################################################################

# Analog XADC Pins
# Only declare these if you want to use pins 15 and 16 as single ended analog inputs. pin 15 -> vaux4, pin16 -> vaux12
#set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports XADC_N_Ch0]
#set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports XADC_P_Ch0]
#set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports XADC_N_Ch1]
#set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports XADC_P_Ch1]

# There are 48 DIP package pins:
#
# - 2 of these are power pins; +3.3V (pin 24) and GND (pin 25)
# - 2 of these are analog input pins (pins 15, 16)
# - The remaining 44 are configurable I/O pins that connect to CMOD-A7 I/O board resources, described below.

set_property -dict {PACKAGE_PIN M3  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p2]}]
set_property -dict {PACKAGE_PIN L3  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p1]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33}             [get_ports IO_CLK_REFIN_10MHz]
set_property -dict {PACKAGE_PIN K3  IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports {IO_AUX[p1]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[7]}]
set_property -dict {PACKAGE_PIN H1  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_TXC]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33}             [get_ports IO_PHY_TXCTL]
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_TXD[0]}]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_TXD[1]}]
set_property -dict {PACKAGE_PIN J3  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_TXD[2]}]
set_property -dict {PACKAGE_PIN J1  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_TXD[3]}]
set_property -dict {PACKAGE_PIN K2  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_MDIO_DATA]
set_property -dict {PACKAGE_PIN L1  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_MDIO_CLOCK]
set_property -dict {PACKAGE_PIN L2  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_RESET_N]
#set_property -dict {PACKAGE_PIN M1  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_INT_N]
#set_property -dict {PACKAGE_PIN N3  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_RXC]
#set_property -dict {PACKAGE_PIN P3  IOSTANDARD LVCMOS33}             [get_ports IO_PHY_RXCTL]
#set_property -dict {PACKAGE_PIN M2  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_RXD[0]}]
#set_property -dict {PACKAGE_PIN N1  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_RXD[1]}]
#set_property -dict {PACKAGE_PIN N2  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_RXD[2]}]
#set_property -dict {PACKAGE_PIN P1  IOSTANDARD LVCMOS33}             [get_ports {IO_PHY_RXD[3]}]
set_property -dict {PACKAGE_PIN R3  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[0]}]
set_property -dict {PACKAGE_PIN T3  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[1]}]
set_property -dict {PACKAGE_PIN R2  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[2]}]
set_property -dict {PACKAGE_PIN T1  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[4]}]
set_property -dict {PACKAGE_PIN T2  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[3]}]
set_property -dict {PACKAGE_PIN U1  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[5]}]
set_property -dict {PACKAGE_PIN W2  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[7]}]
set_property -dict {PACKAGE_PIN V2  IOSTANDARD LVCMOS33}             [get_ports {IO_DOUT[6]}]
set_property -dict {PACKAGE_PIN W3  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p10]}]
set_property -dict {PACKAGE_PIN V3  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p9]}]
set_property -dict {PACKAGE_PIN W5  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[6]}]
set_property -dict {PACKAGE_PIN V4  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[5]}]
set_property -dict {PACKAGE_PIN U4  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[4]}]
set_property -dict {PACKAGE_PIN V5  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p8]}]
set_property -dict {PACKAGE_PIN W4  IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports {IO_AUX[p3]}]
set_property -dict {PACKAGE_PIN U5  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p7]}]
set_property -dict {PACKAGE_PIN U2  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p4]}]
set_property -dict {PACKAGE_PIN W6  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[3]}]
set_property -dict {PACKAGE_PIN U3  IOSTANDARD LVCMOS33}             [get_ports {IO_PMOD[p3]}]
set_property -dict {PACKAGE_PIN U7  IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports {IO_AUX[p2]}]
set_property -dict {PACKAGE_PIN W7  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[2]}]
set_property -dict {PACKAGE_PIN U8  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[0]}]
set_property -dict {PACKAGE_PIN V8  IOSTANDARD LVCMOS33}             [get_ports {IO_DIN[1]}]

###################
#                 #
#  Define clocks  #
#                 #
###################

# Define the 12 MHz XTAL clock.
create_clock -period 83.333 -name XTAL_CLK_12MHz_clock -add [get_ports XTAL_CLK_12MHz]

# Define the 125 MHz Ethernet-RX clock:
#create_clock -period 8.000 -name IO_PHY_RXC_clock -add [get_ports IO_PHY_RXC]

# Define the 10 MHz reference clock:
create_clock -period 100.000 -name IO_CLK_REFIN_10MHz_clock -add [get_ports IO_CLK_REFIN_10MHz]
