/*******************************************************************************
** © Copyright 2011 - 2012 Xilinx, Inc. All rights reserved.
** This file contains confidential and proprietary information of Xilinx, Inc. and 
** is protected under U.S. and international copyright and other intellectual property laws.
*******************************************************************************
**   ____  ____ 
**  /   /\/   / 
** /___/  \  /   Vendor: Xilinx 
** \   \   \/    
**  \   \        
**  /   /          
** /___/   /\     
** \   \  /  \   Kintex-7 PCIe-DMA-DDR3 Base Targeted Reference Design
**  \___\/\___\ 
** 
**  Device: xc7k325t
**  Reference: UG882 
*******************************************************************************
**
**  Disclaimer: 
**
**    This disclaimer is not a license and does not grant any rights to the materials 
**    distributed herewith. Except as otherwise provided in a valid license issued to you 
**    by Xilinx, and to the maximum extent permitted by applicable law: 
**    (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, 
**    AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
**    INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR 
**    FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable (whether in contract 
**    or tort, including negligence, or under any other theory of liability) for any loss or damage 
**    of any kind or nature related to, arising under or in connection with these materials, 
**    including for any direct, or any indirect, special, incidental, or consequential loss 
**    or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered 
**    as a result of any action brought by a third party) even if such damage or loss was 
**    reasonably foreseeable or Xilinx had been advised of the possibility of the same.


**  Critical Applications:
**
**    Xilinx products are not designed or intended to be fail-safe, or for use in any application 
**    requiring fail-safe performance, such as life-support or safety devices or systems, 
**    Class III medical devices, nuclear facilities, applications related to the deployment of airbags,
**    or any other applications that could lead to death, personal injury, or severe property or 
**    environmental damage (individually and collectively, "Critical Applications"). Customer assumes 
**    the sole risk and liability of any use of Xilinx products in Critical Applications, subject only 
**    to applicable laws and regulations governing limitations on product liability.

**  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.

*******************************************************************************/
//This module implements a loopback function, a data checker function, and a data generator 
//function. The module enables specific functions depending on the register bits enable_checker,
//enable_generator and enable_loopback. On the transmit path, the data checker verifies the data 
//transmitted from the host system via the Packet DMA. On the receive path, data can be sourced 
//either by the data generator or transmit data can belooped back and sent to the host system

`timescale 1ps / 1ps

(* CORE_GENERATION_INFO = "k7_pcie_dma_ddr3_base,k7_pcie_dma_ddr3_base_trd_v1_6,{raw_data_packet=2013.2}" *)
module raw_data_packet #
(
  parameter integer AXIS_TDATA_WIDTH      = 64,
  parameter integer ADD_CHIPSCOPE         = 0,
  parameter integer CNTWIDTH              = 10
)

(

  input                                 reset,
  input                                 clk,
  
  // Input from the register interface
  input                                 enable_checker,    // enable/disable checker function
  input                                 enable_generator,  // enable/disable generator function
  input                                 enable_loopback,   // enable/disable loopback function
  input  [15:0]                         pkt_len,           // Length of packets produced by the generator
  output reg                            data_mismatch,     // Set by the checker on a data mismatch

  input  [AXIS_TDATA_WIDTH-1:0]         axi_str_tx_tdata,
  input  [AXIS_TDATA_WIDTH/8 - 1:0]     axi_str_tx_tkeep,
  input                                 axi_str_tx_tvalid,
  input                                 axi_str_tx_tlast,
  input  [31:0]                         axi_str_tx_tuser,
  output                                axi_str_tx_tready,
  
  output [AXIS_TDATA_WIDTH-1:0]         axi_str_rx_tdata,
  output [AXIS_TDATA_WIDTH/8 - 1:0]     axi_str_rx_tkeep,
  output                                axi_str_rx_tvalid,
  output                                axi_str_rx_tlast,
  output [31:0]                         axi_str_rx_tuser,
  input                                 axi_str_rx_tready,
  
  input  [CNTWIDTH-1:0]                 rd_rdy,              // Data word available for read
  input  [CNTWIDTH-1:0]                 wr_rdy               // Free space available in the FIFO


);

  
localparam  AXIS_TKEEP_WIDTH   =  AXIS_TDATA_WIDTH/8; 

//enumerated states
parameter IDLE       = 1'b0;
parameter GEN_PKT    = 1'b1;

reg  cstate = 1'b0;
reg  nstate = 1'b0;
reg  [40*7:0] fsm_name = 'b0;
     
reg  [AXIS_TDATA_WIDTH-1:0]   rx_data_lb = 'b0;
reg                           rx_data_valid_lb = 'b0;
reg                           rx_data_last_lb = 'b0;
reg  [AXIS_TKEEP_WIDTH-1:0]   rx_data_strobe_lb = 'b0;

reg                           hold = 'b0;
reg  [AXIS_TDATA_WIDTH-1:0]   hold_data = 'b0;
reg                           hold_data_last = 'b0;
reg  [AXIS_TKEEP_WIDTH-1:0]   hold_data_strobe = 'b0;

reg  [AXIS_TDATA_WIDTH-1:0]   rx_data_g = 'b0;
reg                           rx_data_valid_g = 'b0;
reg                           rx_data_last_g = 'b0;
reg  [AXIS_TKEEP_WIDTH-1:0]   rx_data_strobe_g = 'b0;
reg  [AXIS_TKEEP_WIDTH/2-1:0] invalid_bytes = 'b0;
reg  [15:0]                   byte_cnt_g = 'b0;
reg  [15:0]                   tag_g = 'b0;
wire [AXIS_TDATA_WIDTH-1:0]   generated_data;

reg                           tx_ready = 'b0;
reg  [AXIS_TDATA_WIDTH-1:0]   tx_data_c = 'b0;
reg                           tx_data_valid_c = 'b0;
reg  [AXIS_TKEEP_WIDTH-1:0]   tx_data_strobe_c;
reg  [15:0]                   tx_pkt_length = 'b0;
reg                           tx_data_last_c = 'b0;
reg  [15:0]                   byte_cnt_c = 'b0;
reg  [15:0]                   expected_tag_c = 'b0;
reg  [15:0]                   next_expected_tag_c = 'b0;
reg                           data_mismatch_0;
reg                           data_mismatch_1;
wire [AXIS_TDATA_WIDTH-1:0]   expected_data;
                                                                              

reg  [AXIS_TKEEP_WIDTH/2-1:0] i = 0;




//----------------------------------------------------------------------//
//                               LOOPBACK                               //
//----------------------------------------------------------------------//
always @ (posedge clk)
begin
  // Pass the hold value or the data available on the 
  // tranmsit lines. If axi_str_rx_ready is not
  // asserted hold the previous values. 
  if (axi_str_rx_tready && hold ) begin
    rx_data_lb        <= hold_data;
    rx_data_valid_lb  <= 1'b1;
    rx_data_strobe_lb <= hold_data_strobe;
    rx_data_last_lb   <= hold_data_last;
  end else if (axi_str_rx_tready) begin
    rx_data_lb        <= axi_str_tx_tdata;
    // pass on only a valid beat to the receive side. At 
    // the start of a run it is possible that tx_tvalid is 
    // asserted but not tx_tready
    rx_data_valid_lb  <= axi_str_tx_tvalid && axi_str_tx_tready;
    rx_data_strobe_lb <= axi_str_tx_tkeep;
    rx_data_last_lb   <= axi_str_tx_tlast;
  end   
  
  tx_ready <= axi_str_rx_tready; 
end  

// valid data beat = axi_str_tx_tvalid && axi_str_tx_tready
// if there is valid data beat on transmit and receive is not 
// ready hold the value
always @ (posedge clk)
begin
  if (!axi_str_rx_tready && !hold && axi_str_tx_tvalid && axi_str_tx_tready) begin
    hold <= 1'b1;
    hold_data        <= axi_str_tx_tdata;
    hold_data_strobe <= axi_str_tx_tkeep;
    hold_data_last   <= axi_str_tx_tlast;
  end else if (axi_str_rx_tready) begin
    hold <= 1'b0;
  end  
end  

//----------------------------------------------------------------------//
//                               CHECKER                                //
//----------------------------------------------------------------------//

// The Checker compares transmitted data against the expected data.
// The expected data has the following pattern
// The first DW (64 bits/8 bytes) of a packet carries 
// the length info in the first 2 bytes and a 2 byte  
// tag repeated thrice. All subsequent DW have the
// the tag number repeated 4 times. 
// The tag num increments by 1 from one packet to the
// next

assign expected_data = {AXIS_TKEEP_WIDTH/2{expected_tag_c}};

always @ (posedge clk)
begin
  tx_data_c         <= axi_str_tx_tdata;
  tx_data_valid_c   <= axi_str_tx_tvalid;
  tx_pkt_length     <= axi_str_tx_tuser[15:0];
  tx_data_strobe_c  <= axi_str_tx_tkeep;
  tx_data_last_c    <= axi_str_tx_tlast;
end  

// The data comparison is spilt over two processes to help with timing. 
always @ (posedge clk) 
begin
  if (!enable_checker || enable_loopback) begin
      data_mismatch_0 <= 1'b0;
  end else if (tx_data_valid_c && byte_cnt_c == 0) begin
    if (tx_data_c[AXIS_TDATA_WIDTH/2-1:0] != {expected_data[AXIS_TDATA_WIDTH/2-1:16],tx_pkt_length}) begin
      data_mismatch_0 <= 1'b1;
      $display("[%t] Raw data Packet Error: expected = %h  received = %h",$time, expected_data,tx_data_c);
    end    
  end else if (tx_data_valid_c && tx_data_last_c) begin
    for (i= 0; i <AXIS_TKEEP_WIDTH/2; i= i+1) begin  
      if (tx_data_strobe_c[i]  == 1 && tx_data_c[(i*8)+:8] != expected_data[(i*8)+:8]) begin
        data_mismatch_0 <= 1'b1; 
        $display("[%t] Raw data Packet Error: expected = %h  received = %h",$time, expected_data,tx_data_c);
      end  
    end
  end else if (tx_data_valid_c) begin
    if (tx_data_c[AXIS_TDATA_WIDTH/2-1:0] != expected_data[AXIS_TDATA_WIDTH/2-1:0]) begin    
      data_mismatch_0 <= 1'b1;  
      $display("[%t] Raw data Packet Error: expected = %h  received = %h",$time, expected_data,tx_data_c );
    end  
  end 
  
end  

always @ (posedge clk) 
begin
  if (!enable_checker || enable_loopback) begin
      data_mismatch_1 <= 1'b0;
  end else if (tx_data_valid_c && tx_data_last_c) begin
    for (i= AXIS_TKEEP_WIDTH/2; i <AXIS_TKEEP_WIDTH; i= i+1) begin  
      if (tx_data_strobe_c[i]  == 1 && tx_data_c[(i*8)+:8] != expected_data[(i*8)+:8]) begin
        data_mismatch_1 <= 1'b1; 
        $display("[%t] Raw data Packet Error: expected = %h  received = %h",$time, expected_data,tx_data_c);
      end  
    end
  end else if (tx_data_valid_c) begin
    if (tx_data_c[AXIS_TDATA_WIDTH-1:AXIS_TDATA_WIDTH/2] != expected_data[AXIS_TDATA_WIDTH-1:AXIS_TDATA_WIDTH/2]) begin    
      data_mismatch_1 <= 1'b1;  
      $display("[%t] Raw data Packet Error: expected = %h  received = %h",$time, expected_data,tx_data_c );
    end  
  end 
  
end  

// data_mismatch is a sticky bit. The software polls this
// register at regular intervals. 
// This bit is set only when enable_checker is 1
always @ (posedge clk)
begin
  data_mismatch <= data_mismatch_0 || data_mismatch_1;
end


// Expected tag is updated at the end of a packet  
always @ (posedge clk) 
begin
  if (reset || !enable_checker || enable_loopback) begin
    expected_tag_c <= 0;
    next_expected_tag_c <= 0;
  end else if (tx_data_valid_c && byte_cnt_c == 0) begin
    next_expected_tag_c <= tx_data_c[AXIS_TDATA_WIDTH-1:AXIS_TDATA_WIDTH-16] + 1;  
  end else if (tx_data_valid_c && tx_data_last_c) begin
    expected_tag_c <= next_expected_tag_c;  
  end  
end  

// Could use axi_str_tx_tlast to determine the start of
// the next packet, but byte count allows to check
// the actual payload length
always @(posedge clk)
begin
  if (reset == 1'b1 || enable_loopback) begin
    byte_cnt_c <= 0;
  end else if (tx_data_valid_c && byte_cnt_c == 0) begin
    byte_cnt_c <= tx_data_c[15:0] - AXIS_TKEEP_WIDTH;
  end else if (tx_data_valid_c && byte_cnt_c < AXIS_TKEEP_WIDTH) begin
    byte_cnt_c <= 0;
  end else if (tx_data_valid_c) begin
    byte_cnt_c <= byte_cnt_c - AXIS_TKEEP_WIDTH;
  end
end

//----------------------------------------------------------------------//
//                               GENERATOR                              //
//----------------------------------------------------------------------//
// The data generator follows the same data pattern as the checker.
// It generates packets of a fixed length. This fixed length is pkt_len
// programmed by software
always @ (posedge clk) begin
  if (reset == 1'b1)
    cstate <= IDLE;
  else 
    cstate <= nstate;
end

// if enable generator is set to 0 in a middle of the packet,
// the generator completes the packet and then stops generating 
// any more packets
always@(cstate, enable_generator, byte_cnt_g, axi_str_rx_tready) begin
  case (cstate)
    IDLE: begin
      if (enable_generator && axi_str_rx_tready) begin
        nstate <= GEN_PKT;
      end else begin
        nstate <= IDLE;
      end
      fsm_name <= "IDLE";
    end

    GEN_PKT: begin
      if (byte_cnt_g <= 8 && axi_str_rx_tready) begin
        nstate <= IDLE;
      end else begin
        nstate <= GEN_PKT;
      end
      fsm_name <= "GEN_PKT";
    end

    default : begin
      nstate <= IDLE;
    end

  endcase
end

always @(posedge clk)
begin
  if (rx_data_last_g  && !axi_str_rx_tready)
    byte_cnt_g <= byte_cnt_g;
  else if (cstate == IDLE) 
    byte_cnt_g <= pkt_len - AXIS_TKEEP_WIDTH;
  else if (byte_cnt_g < AXIS_TKEEP_WIDTH && axi_str_rx_tready ) 
    byte_cnt_g <= 0;
  else if (axi_str_rx_tready) 
    byte_cnt_g <= byte_cnt_g - AXIS_TKEEP_WIDTH;
end

always @(posedge clk)
begin
  if (rx_data_last_g  && !axi_str_rx_tready)
    rx_data_valid_g <= rx_data_valid_g;
  else if (cstate == IDLE && nstate != GEN_PKT) 
    rx_data_valid_g <= 1'b0;
  else 
    rx_data_valid_g <= 1'b1;
end

always @(posedge clk)
begin
  if (!enable_generator && cstate == IDLE) 
    tag_g <= 0;
  else if (cstate == GEN_PKT && nstate == IDLE) 
    tag_g <= tag_g + 1;
end


always @(posedge clk)
begin
  if (cstate == IDLE) begin
    invalid_bytes <= AXIS_TKEEP_WIDTH - (pkt_len % AXIS_TKEEP_WIDTH);
  end
  
  if (rx_data_last_g  && !axi_str_rx_tready)
    rx_data_strobe_g <= rx_data_strobe_g;
  else if (cstate == GEN_PKT && nstate == IDLE && invalid_bytes < 8) 
    rx_data_strobe_g <= {AXIS_TKEEP_WIDTH{1'b1}} >> invalid_bytes;
  else  
    rx_data_strobe_g <= {AXIS_TKEEP_WIDTH{1'b1}};
end

always @(posedge clk)
begin
  if (rx_data_last_g  && !axi_str_rx_tready)
    rx_data_last_g <= rx_data_last_g;
  else if (cstate == GEN_PKT && nstate == IDLE) 
    rx_data_last_g <= 1;
  else  
    rx_data_last_g <= 0;
end

assign generated_data = {AXIS_TKEEP_WIDTH{tag_g}};

always @(posedge clk)
begin
  if (rx_data_last_g  && !axi_str_rx_tready)
    rx_data_g <= rx_data_g;
  else if (cstate == IDLE ) 
    rx_data_g <=  {generated_data[AXIS_TDATA_WIDTH-1:16],pkt_len};
  else if (axi_str_rx_tready)  
    rx_data_g <=  {AXIS_TKEEP_WIDTH{tag_g}};
end



// Data source for receive data is either looped back 
// transmit data or data from the generator.

assign  axi_str_tx_tready = (enable_loopback) ? tx_ready : 1'b1;
                             //(enable_checker) ? 1'b1
                                              //: 1'b0;
                                              
assign  axi_str_rx_tdata  = (enable_loopback) ? rx_data_lb 
                                              : rx_data_g;      

assign  axi_str_rx_tvalid = (enable_loopback) ? rx_data_valid_lb 
                                              : rx_data_valid_g;  


assign  axi_str_rx_tkeep  = (enable_loopback) ? rx_data_strobe_lb 
                                              : rx_data_strobe_g;  

assign  axi_str_rx_tlast  = (enable_loopback) ? rx_data_last_lb 
                                              : rx_data_last_g;  

assign  axi_str_rx_tuser  = (enable_loopback) ? tx_pkt_length 
                                              : pkt_len;  

`ifdef CHIPSCOPE
wire [31:0]   TRIG;
wire [255:0]  DATA;
wire [35:0]   CONTROL;

assign TRIG[0]       = enable_checker;
assign TRIG[1]       = data_mismatch;
assign TRIG[2]       = tx_data_valid_c;
assign TRIG[3]       = axi_str_tx_tvalid;
assign TRIG[4]       = axi_str_tx_tready;
assign TRIG[5]       = data_mismatch_0;
assign TRIG[6]       = data_mismatch_1;
assign TRIG[31:7]    = 'b0;

assign DATA[0]       = enable_checker;
assign DATA[1]       = data_mismatch;
assign DATA[2]       = axi_str_tx_tvalid;
assign DATA[3]       = axi_str_tx_tready;
assign DATA[67:4]    = axi_str_tx_tdata;
assign DATA[83:68]   = axi_str_tx_tuser[15:0];
assign DATA[84]      = axi_str_tx_tlast;
assign DATA[92:85]   = axi_str_tx_tkeep;
assign DATA[156:93]  = tx_data_c;
assign DATA[157]     = tx_data_valid_c;
assign DATA[173:158] = tx_pkt_length;
assign DATA[181:174] = tx_data_strobe_c;
assign DATA[182]     = tx_data_last_c;
assign DATA[197:183] = expected_tag_c;
assign DATA[213:198] = byte_cnt_c;
assign DATA[226:214] = rd_rdy;
assign DATA[227]     = data_mismatch_0;
assign DATA[228]     = data_mismatch_1;
assign DATA[255:229] = 'b0;




generate
if (ADD_CHIPSCOPE == 1) 

  chipscope_ila ila (
      .CONTROL(CONTROL), // INOUT BUS [35:0]
      .CLK(clk), // IN
      .DATA(DATA), // IN BUS [255:0]
      .TRIG0(TRIG) // IN BUS [31:0]
  );
endgenerate

generate
if (ADD_CHIPSCOPE == 1) 
  chipscope_icon icon (
      .CONTROL0(CONTROL) // INOUT BUS [35:0]
  );
endgenerate


`endif

endmodule

