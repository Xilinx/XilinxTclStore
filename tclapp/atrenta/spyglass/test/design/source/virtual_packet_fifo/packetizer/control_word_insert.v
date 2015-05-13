
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

//-----------------------------------------------------------------------------
// MODULE control_word_insert
// The purpose of this module is to insert a control word at the start of each
// packet. Packet length and Strb value are stored as a part of the control word.
// The size of the packet may range from 64B to 16KB. The packet length information
// is conveyed through a side band signal cwi_axi_str_tuser_in, which is available at the 
// start of each packet(first data cycle). 
//-----------------------------------------------------------------------------

//`timescale 1 ps/ 1 ps

module control_word_insert #(
     parameter AXIS_TDATA_WIDTH = 64,              // Datawidth of the AXI Stream Data Bus
     parameter STRB_WIDTH       = 8,               // Strb width
     parameter REM_WIDTH        = 3,               // Rem  width
     parameter PKT_LEN          = 16)              // length of the packet
  (
     input                             rst_n,  
     // AXI-ST interface before Control Word Insertion
     input                             axi_str_aclk,
     input [AXIS_TDATA_WIDTH-1:0]      cwi_axi_str_tdata_in,
     input                             cwi_axi_str_tvalid_in,
     input                             cwi_axi_str_tlast_in,
     input                             cwi_axi_str_tready_in,  
     input [PKT_LEN-1:0]               cwi_axi_str_tuser_in,
     // AXI-ST MINIMAL interface after Control Word Insertion
     output  [AXIS_TDATA_WIDTH-1:0]    cwi_axi_str_tdata_out,
     output                            cwi_axi_str_tvalid_out,
     output                            cwi_axi_str_tready_out
  );

localparam SOP_DETECT = 1'b0,
           EOP_DETECT = 1'b1;

localparam STUFF_WIDTH = AXIS_TDATA_WIDTH - PKT_LEN - REM_WIDTH;

reg                             fsm_state = SOP_DETECT;
reg                             axi_str_tvalid_in_d1 = 'd0;
reg  [AXIS_TDATA_WIDTH-1:0]     axi_str_tdata_in_d1 = 'd0;
reg                             tlast_for_one_clk = 1'b0;
reg                             hold_data = 1'b0;
reg                             hold_valid = 1'b0;

wire [REM_WIDTH-1:0]            axi_str_tstrb_fifo_in;
wire [STUFF_WIDTH-1:0]          zero_padding;
wire                            back_to_back_pkt_occurance;
wire                            sop;

/***********************************************************************************
// State Machine to detect the Start of Packet
// The state machine has two states
// 1. SOP_DETECT
// 2. EOP_DETECT
// The SOP_DETECT state hunts for start of each packet and sop is generated whenever
// state machine is in this state. For  single cycle packets, i.e.,SOP and TLAST in
// the same clock cycle, the state machine remains in the same state, as it has to
// hunt for next SOP, otherwise it moves to the next state EOP_DETECT. The state
// machine remains in this state untill it encounters EOP, then moves to SOP_DETECT.
// 
************************************************************************************/

always@(posedge axi_str_aclk)
begin
  if (~rst_n)
    fsm_state  <= SOP_DETECT;
  else
  begin
  case(fsm_state)
  SOP_DETECT:
                begin
                    if(cwi_axi_str_tvalid_in & cwi_axi_str_tready_out)
                    begin
                      if(cwi_axi_str_tlast_in)
                        fsm_state <= SOP_DETECT;
                      else
                        fsm_state <= EOP_DETECT;
                    end
                    else
                        fsm_state <= SOP_DETECT;
                end
  EOP_DETECT:
                begin
                    if(cwi_axi_str_tvalid_in & cwi_axi_str_tready_out)
                    begin
                      if(cwi_axi_str_tlast_in)
                          fsm_state <= SOP_DETECT;
                      else
                          fsm_state <= EOP_DETECT;
                    end
                    else
                        fsm_state <= EOP_DETECT;
                end
  endcase
  end
end

assign sop = (cwi_axi_str_tvalid_in & (fsm_state == SOP_DETECT) & cwi_axi_str_tready_out);

// Write side AXI signals are delayed to align with Control word insertion

always@(posedge axi_str_aclk)
begin
  if(~rst_n)
      axi_str_tvalid_in_d1 <= 'd0;
  else  //if(cwi_axi_str_tready_out | tlast_for_one_clk)
      axi_str_tvalid_in_d1 <= cwi_axi_str_tready_out & cwi_axi_str_tvalid_in;
end

  always @(posedge axi_str_aclk)
    if (~rst_n | cwi_axi_str_tready_in)
      hold_valid  <= 1'b0;
    else if (cwi_axi_str_tvalid_out && ~cwi_axi_str_tready_in)  
      hold_valid  <= 1'b1;


always@(posedge axi_str_aclk)
begin
  if(cwi_axi_str_tready_out)
  begin
      axi_str_tdata_in_d1  <= cwi_axi_str_tdata_in;
  end
end

assign axi_str_tstrb_fifo_in = (cwi_axi_str_tuser_in%STRB_WIDTH);

assign zero_padding = {STUFF_WIDTH{1'b0}};

// Insertion of the Control word( Pkt length and Tstrb)
// If back to back packets occur, sop will be generated for 2 cycles
// In the second cycle, control word is inserted. The first cycle has incoming data
assign cwi_axi_str_tdata_out  = back_to_back_pkt_occurance?axi_str_tdata_in_d1:sop?{zero_padding,axi_str_tstrb_fifo_in,cwi_axi_str_tuser_in}:axi_str_tdata_in_d1;

assign cwi_axi_str_tvalid_out = sop ? 'd1 : 
                        (axi_str_tvalid_in_d1 | hold_valid);

always@(posedge axi_str_aclk)
begin
 tlast_for_one_clk <= (cwi_axi_str_tvalid_in & cwi_axi_str_tready_out & cwi_axi_str_tlast_in) ? 1'b1 : 1'b0;
end
// Back pressure the source, if back to back packets occur.
assign back_to_back_pkt_occurance = tlast_for_one_clk;  // & sop;

  always @(posedge axi_str_aclk)
    if (hold_data & cwi_axi_str_tready_in)
      hold_data <= 1'b0;
    else if (tlast_for_one_clk & ~cwi_axi_str_tready_in)
      hold_data <= 1'b1;
      
assign cwi_axi_str_tready_out = (back_to_back_pkt_occurance | hold_data) ? 1'b0 : cwi_axi_str_tready_in;

endmodule
