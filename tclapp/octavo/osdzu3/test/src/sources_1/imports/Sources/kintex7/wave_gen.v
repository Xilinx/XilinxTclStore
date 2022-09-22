//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : wave_gen.v
//  Parent   : None
//  Children : Many
//
//  Description: 
//     This is the top level of the wave generator.
//     It directly instantiates the I/O pads and all the submodules required
//     to implement the design.
//
//  Parameters:
//     BAUD_RATE:     Desired Baud rate for both RX and TX
//     CLOCK_RATE_RX: Clock rate for the RX domain
//     CLOCK_RATE_TX: Clock rate for the TX domain
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//    Some exist, embedded within the submodules. See the submodule
//    descriptions.
//

`timescale 1ns/1ps


module wave_gen (
  input            clk_pin_p,      // Clock input (from pin)
  input            clk_pin_n,      //   - differential pair
  input            rst_pin,        // Active HIGH reset (from pin)

  // RS232 signals
  input            rxd_pin,        // RS232 RXD pin
  output           txd_pin,        // RS232 RXD pin

  // Loopback selector
  input            lb_sel_pin,     // Loopback selector 

  // DAC output signals
  output           spi_clk_pin,    // Serial clock
  output           spi_mosi_pin,   // Serial data
  output           dac_cs_n_pin,   // DAC chip select (active low)
  output           dac_clr_n_pin,  // DAC clear (or reset - active low)


  // LED outputs
  output     [7:0] led_pins         // 8 LED outputs
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter BAUD_RATE           = 115_200;   

  parameter CLOCK_RATE_RX       = 200_000_000;
//  parameter CLOCK_RATE_TX       = 193_750_000; 
  parameter CLOCK_RATE_TX       = 166_667_000;     
   
  // Minimum width of a pulse to cross between clk_rx and clk_tx
  parameter PW                  = 3;  

  // Number of bits of address for the Sample RAM - RAM can hold 2^NSAMP_WID
  // Since NSAMP is coded "naturally" (from 1 to 2**NSAMP_WID, rather than
  // from 0 to 2**(NSAMP_WID)-1), an extra bit is required in things that
  // carry the actual value of nsamp. However, the RAM address is coded
  // 0 to 2**NSAMP_WID-1
  parameter NSAMP_WID           = 10; 

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  // To/From IBUFG/OBUFG
  // No pin for clock - the IBUFG is internal to clk_gen
  wire        rst_i;          
  wire        rxd_i;         
  wire        txd_o;
  wire        lb_sel_i;
  wire        spi_clk_o;
  wire        spi_mosi_o;
  wire        dac_cs_n_o;
  wire [7:0]  led_o;

  // From Clock Generator
  wire        clk_rx;         // Receive clock
  wire        clk_tx;         // Transmit clock
  wire        clk_samp;       // Sample clock
  wire        en_clk_samp;    // Enable for clk_samp, syncronous to clk_tx
  wire        clock_locked;   // Locked signal from clk_core

  // From Reset Generator
  wire        rst_clk_rx;     // Reset, synchronized to clk_rx
  wire        rst_clk_tx;     // Reset, synchronized to clk_tx
  wire        rst_clk_samp;   // Reset, synchronized to clk_samp

  // From the RS232 receiver
  wire        rxd_clk_rx;     // RXD signal synchronized to clk_rx
  wire        rx_data_rdy;    // New character is ready
  wire [7:0]  rx_data;        // New character

  // From the command parser to the response generator
  wire        send_char_val;  // A character is ready to be sent
  wire [7:0]  send_char;      // Character to be sent

  wire        send_resp_val;  // A response is requested
  wire [1:0]  send_resp_type; // Type of response - see localparams
  wire [15:0] send_resp_data; // Data to be output


  // From the command parser to bus clock crossers
  wire [NSAMP_WID:0] 
              nsamp_clk_rx;       // Current value of nsamp
  wire        nsamp_new_clk_rx;   // A new nsamp is available
  
  wire [15:0] pre_clk_rx;         // Current value of prescale
  wire        pre_new_clk_rx;     // A new prescale is available

  wire [15:0] spd_clk_rx;         // Current value of speed
  wire        spd_new_clk_rx;     // A new speed is available

  // From the command parser to the sample generator
  wire        samp_gen_go_clk_rx; // Enable for sample generator

  // From the command parser To Sample RAM
  wire [15:0] cmd_samp_ram_din; // Data to write to sample RAM
  wire [NSAMP_WID-1:0]  
              cmd_samp_ram_addr;// Address for sample RAM read or write
  wire        cmd_samp_ram_we;  // Write enable to sample RAM

  // From the response generator back to the command parser
  wire        send_resp_done;   // The response generation is complete

  // From the response generator to character FIFO
  wire [7:0]  char_fifo_din;    // Character to push into the FIFO
  wire        char_fifo_wr_en;  // Write enable (push) for the FIFO

  // From the character FIFO
  wire [7:0]  char_fifo_dout;   // Character to be popped from the FIFO
  wire        char_fifo_full;   // The character FIFO is full
  wire        char_fifo_empty;  // The character FIFO is full


  // From the UART transmitter
  wire        char_fifo_rd_en;  // Pop signal to the char FIFO
  wire        txd_tx;           // The transmit serial signal

  // From the Sample RAM
  wire [15:0] cmd_samp_ram_dout;     // Data read back to the command parser
  wire [15:0] samp_gen_samp_ram_dout;// Data read to the sample generator

  // From the clock crossers for nsamp, pre, and speed
  wire [NSAMP_WID:0] 
              nsamp_clk_tx;       // Current value of nsamp
  wire        nsamp_new_clk_tx;   // A new nsamp is available
  
  wire [15:0] pre_clk_tx;         // Current value of prescale
  wire        pre_new_clk_tx;     // A new prescale is available

  wire [15:0] spd_clk_tx;         // Current value of speed
  wire        spd_new_clk_tx;     // A new speed is available

  // From the sample generator

  wire [NSAMP_WID-1:0] 
              samp_gen_samp_ram_addr; // Address to sample RAM
  wire [15:0] samp;               // Sample output
  wire        samp_val;           // New sample is available

//***************************************************************************
// Code
//***************************************************************************

  // Instantiate input/output buffers
  IBUF IBUF_rst_i0      (.I (rst_pin),      .O (rst_i));
  IBUF IBUF_rxd_i0      (.I (rxd_pin),      .O (rxd_i));
  IBUF IBUF_lb_sel_i0   (.I (lb_sel_pin),   .O (lb_sel_i));

  OBUF OBUF_txd         (.I(txd_o),         .O(txd_pin));
  OBUF OBUF_spi_clk     (.I(spi_clk_o),     .O(spi_clk_pin));
  OBUF OBUF_spi_mosi    (.I(spi_mosi_o),    .O(spi_mosi_pin));
  OBUF OBUF_dac_cs_n    (.I(dac_cs_n_o),    .O(dac_cs_n_pin));
  OBUF OBUF_dac_clr_n   (.I(dac_clr_n_o),  .O(dac_clr_n_pin));


  OBUF OBUF_led_i0      (.I(led_o[0]),      .O(led_pins[0]));
  OBUF OBUF_led_i1      (.I(led_o[1]),      .O(led_pins[1]));
  OBUF OBUF_led_i2      (.I(led_o[2]),      .O(led_pins[2]));
  OBUF OBUF_led_i3      (.I(led_o[3]),      .O(led_pins[3]));
  OBUF OBUF_led_i4      (.I(led_o[4]),      .O(led_pins[4]));
  OBUF OBUF_led_i5      (.I(led_o[5]),      .O(led_pins[5]));
  OBUF OBUF_led_i6      (.I(led_o[6]),      .O(led_pins[6]));
  OBUF OBUF_led_i7      (.I(led_o[7]),      .O(led_pins[7]));

  // Instantiate the clock generator
  clk_gen clk_gen_i0 (
    .clk_pin_p       (clk_pin_p),       // Input clock pin - IBUFG is in core
    .clk_pin_n       (clk_pin_n),       //   - differential pair
    .rst_i           (rst_i),           // Asynchronous input from IBUF

    .rst_clk_tx      (rst_clk_tx),      // For clock divider

    .pre_clk_tx      (pre_clk_tx),      // Current divider

    .clk_rx          (clk_rx),          // Receive clock
    .clk_tx          (clk_tx),          // Transmit clock
    .clk_samp        (clk_samp),        // Sample clock

    .en_clk_samp     (en_clk_samp),     // Enable for clk_samp
    .clock_locked    (clock_locked)     // Locked signal from clk_core
  );

  // Instantiate the reset generator
  rst_gen rst_gen_i0 (
    .clk_rx          (clk_rx),          // Receive clock
    .clk_tx          (clk_tx),          // Transmit clock
    .clk_samp        (clk_samp),        // Sample clock

    .rst_i           (rst_i),           // Asynchronous input - from IBUF
    .clock_locked    (clock_locked),    // Locked signal from clk_core

    .rst_clk_rx      (rst_clk_rx),      // Reset, synchronized to clk_rx
    .rst_clk_tx      (rst_clk_tx),      // Reset, synchronized to clk_tx
    .rst_clk_samp    (rst_clk_samp)     // Reset, synchronized to clk_samp
  );


  // Instantiate the UART receiver
  uart_rx #(
    .BAUD_RATE   (BAUD_RATE),
    .CLOCK_RATE  (CLOCK_RATE_RX)
  ) uart_rx_i0 (
    .clk_rx      (clk_rx),              // Receive clock
    .rst_clk_rx  (rst_clk_rx),          // Reset, synchronized to clk_rx 

    .rxd_i       (rxd_i),               // RS232 receive pin
    .rxd_clk_rx  (rxd_clk_rx),          // RXD pin after sync to clk_rx
    
    .rx_data_rdy (rx_data_rdy),         // New character is ready
    .rx_data     (rx_data),             // New character
    .frm_err     ()                     // Framing error (unused)
  );

  // Instantiate the command parser
  cmd_parse #(
    .PW          (PW),
    .NSAMP_WID   (NSAMP_WID)
  ) cmd_parse_i0 (
    .clk_rx            (clk_rx),         // Clock input
    .rst_clk_rx        (rst_clk_rx),     // Reset - synchronous to clk_rx

    .rx_data           (rx_data),        // Character to be parsed
    .rx_data_rdy       (rx_data_rdy),    // Ready signal for rx_data

    // From Character FIFO
    .char_fifo_full    (char_fifo_full), // The char_fifo is full

    // To/From Response generator
    .send_char_val     (send_char_val),  // A character is ready to be sent
    .send_char         (send_char),      // Character to be sent

    .send_resp_val     (send_resp_val),  // A response is requested
    .send_resp_type    (send_resp_type), // Type of response - see localparams
    .send_resp_data    (send_resp_data), // Data to be output

    .send_resp_done    (send_resp_done), // The response generation is complete

    // To the bus clock crossers
    .nsamp_clk_rx      (nsamp_clk_rx),   // Current value of nsamp
    .nsamp_new_clk_rx  (nsamp_new_clk_rx), // A new nsamp is available

    .pre_clk_rx        (pre_clk_rx),     // Current value of prescale
    .pre_new_clk_rx    (pre_new_clk_rx), // A new prescale is available

    .spd_clk_rx        (spd_clk_rx),     // Current value of speed
    .spd_new_clk_rx    (spd_new_clk_rx), // A new speed is available

    // To the sample generator
    .samp_gen_go_clk_rx(samp_gen_go_clk_rx), // Enable for sample generator

    // To/From Sample RAM
    .cmd_samp_ram_din  (cmd_samp_ram_din), // Data to write to sample RAM
    .cmd_samp_ram_addr (cmd_samp_ram_addr),// Address for sample RAM rd or wr
    .cmd_samp_ram_we   (cmd_samp_ram_we),  // Write enable to sample RAM
    .cmd_samp_ram_dout (cmd_samp_ram_dout) // Read data from sample RAM
  );

  // Instantiate sample RAM

  samp_ram samp_ram_i0 (
    .clka       (clk_rx),
    .dina       (cmd_samp_ram_din), // Bus [15 : 0] 
    .addra      (cmd_samp_ram_addr), // Bus [9 : 0] 
    .wea        (cmd_samp_ram_we), // Bus [0 : 0] 
    .douta      (cmd_samp_ram_dout), // Bus [15 : 0] 
    .clkb       (clk_samp),
    .dinb       (16'b0), // Bus [15 : 0] 
    .addrb      (samp_gen_samp_ram_addr), // Bus [9 : 0] 
    .web        (1'b0), // Bus [0 : 0]  - we don't write on port B
    .doutb      (samp_gen_samp_ram_dout) // Bus [15 : 0] 
  );

  // Instantiate the Response Generator
  resp_gen resp_gen_i0 (
    .clk_rx             (clk_rx),         // Clock input
    .rst_clk_rx         (rst_clk_rx),     // Reset - synchronous to clk_rx

    // From Character FIFO
    .char_fifo_full     (char_fifo_full), // The char_fifo is full

    // To/From the Command Parser
    .send_char_val      (send_char_val),  // A character is ready to be sent
    .send_char          (send_char),      // Character to be sent

    .send_resp_val      (send_resp_val),  // A response is requested
    .send_resp_type     (send_resp_type), // Type of response - see localparams
    .send_resp_data     (send_resp_data), // Data to be output

    .send_resp_done     (send_resp_done), // The response generation is complete

    // To character FIFO
    .char_fifo_din      (char_fifo_din),  // Character to push into the FIFO
    .char_fifo_wr_en    (char_fifo_wr_en) // Write enable (push) for the FIFO
  );


  // Instantiate the Character FIFO - Core generator module

  char_fifo char_fifo_i0 (
    .din        (char_fifo_din), // Bus [7 : 0] 
    .rd_clk     (clk_tx),
    .rd_en      (char_fifo_rd_en),
    .rst        (rst_i),          // ASYNCHRONOUS reset - to both sides
    .wr_clk     (clk_rx),
    .wr_en      (char_fifo_wr_en),
    .dout       (char_fifo_dout), // Bus [7 : 0] 
    .empty      (char_fifo_empty),
    .full       (char_fifo_full)
  );

  // Instantiate the UART transmitter
  uart_tx #(
    .BAUD_RATE    (BAUD_RATE),
    .CLOCK_RATE   (CLOCK_RATE_TX)
  ) uart_tx_i0 (
    .clk_tx             (clk_tx),          // Clock input
    .rst_clk_tx         (rst_clk_tx),      // Reset - synchronous to clk_tx

    .char_fifo_empty    (char_fifo_empty), // Empty signal from char FIFO (FWFT)
    .char_fifo_dout     (char_fifo_dout),  // Data from the char FIFO
    .char_fifo_rd_en    (char_fifo_rd_en), // Pop signal to the char FIFO

    .txd_tx             (txd_tx)           // The transmit serial signal
  );

  // Instantiate the loopback controller
  lb_ctl lb_ctl_i0 (
    .clk_tx     (clk_tx),          // Clock input
    .rst_clk_tx (rst_clk_tx),      // Active HIGH reset - synchronous to clk_tx

    .lb_sel_i   (lb_sel_i),        // Undebounced slide switch input

    .txd_tx     (txd_tx),          // Normal transmit data
    .rxd_clk_rx (rxd_clk_rx),      // RXD signal

    .txd_o      (txd_o)            // Transmit data to pin
  );

  // Instantiate the three clock crossing modules for nsamp, speed, and
  // prescale

  clkx_bus #(
    .PW    (PW),
    .WIDTH (NSAMP_WID+1)
  ) clkx_nsamp_i0 (
    .clk_src      (clk_rx),
    .rst_clk_src  (rst_clk_rx),
    .clk_dst      (clk_tx),
    .rst_clk_dst  (rst_clk_tx),
    .bus_src      (nsamp_clk_rx),
    .bus_new_src  (nsamp_new_clk_rx),
    .bus_dst      (nsamp_clk_tx),
    .bus_new_dst  (nsamp_new_clk_tx)
  );

  clkx_bus #(
    .PW    (PW),
    .WIDTH (16)
  ) clkx_pre_i0 (
    .clk_src      (clk_rx),
    .rst_clk_src  (rst_clk_rx),
    .clk_dst      (clk_tx),
    .rst_clk_dst  (rst_clk_tx),
    .bus_src      (pre_clk_rx),
    .bus_new_src  (pre_new_clk_rx),
    .bus_dst      (pre_clk_tx),
    .bus_new_dst  (pre_new_clk_tx)
  );

  clkx_bus #(
    .PW    (PW),
    .WIDTH (16)
  ) clkx_spd_i0 (
    .clk_src      (clk_rx),
    .rst_clk_src  (rst_clk_rx),
    .clk_dst      (clk_tx),
    .rst_clk_dst  (rst_clk_tx),
    .bus_src      (spd_clk_rx),
    .bus_new_src  (spd_new_clk_rx),
    .bus_dst      (spd_clk_tx),
    .bus_new_dst  (spd_new_clk_tx)
  );

  // Instantiate the sample generator

  samp_gen #(
    .NSAMP_WID  (NSAMP_WID)
  ) samp_gen_i0 (
    .clk_tx       (clk_tx),       // Clock input
    .rst_clk_tx   (rst_clk_tx),   // Active HIGH reset - synchronous to clk_tx
    .clk_samp     (clk_samp),     // Clock input
    .rst_clk_samp (rst_clk_samp), // Active HIGH reset - synchronous to clk_samp
    .en_clk_samp  (en_clk_samp),  // Last clk_tx phase of clk_samp
    .samp_gen_go_clk_rx  (samp_gen_go_clk_rx), // Starts samp_gen - on clk_rx

    .nsamp_clk_tx (nsamp_clk_tx), // Current value of nsamp
    .spd_clk_tx   (spd_clk_tx),   // Current value of speed

    .samp_gen_samp_ram_addr  (samp_gen_samp_ram_addr), // Address to sample RAM
    .samp_gen_samp_ram_dout  (samp_gen_samp_ram_dout), // Data from samp RAM
    .samp         (samp),         // Sample output
    .samp_val     (samp_val),     // New sample is available
    .led_o        (led_o)         // Upper bits of samples sent to LEDs
  );

  // Instantiat the SPI controller
  dac_spi dac_spi_i0 (
    .clk_tx        (clk_tx),       // Clock input
    .rst_clk_tx    (rst_clk_tx),   // Active HIGH reset - synchronous to clk_tx
    .en_clk_samp   (en_clk_samp),  // Last clk_tx phase of clk_samp
    .samp          (samp),         // Sample output
    .samp_val      (samp_val),     // New sample is available
    // Control to the A to D converter
    .spi_clk_o     (spi_clk_o),    // Clock for SPI - generated by DDR flop
    .spi_mosi_o    (spi_mosi_o),   // SPI master-out-slave-in data bit
    .dac_cs_n_o    (dac_cs_n_o),   // Chip select for DAC
    .dac_clr_n_o   (dac_clr_n_o)   // Active low clear
  );


endmodule
