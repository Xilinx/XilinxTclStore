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
// MODULE control_word_strip.v 
// The purpose of this module is to strip off the control word and to extract
// the packet length and strb information stored in the first data cycle(SOP)
// of the packet. Also, it generates tlast from the packet length.
//-----------------------------------------------------------------------------

//`timescale 1 ps/ 1 ps

module control_word_strip #(
     parameter AXIS_TDATA_WIDTH = 64,              // Datawidth of the AXI Stream Data Bus
     parameter STRB_WIDTH       = 8,
     parameter REM_WIDTH        = 3,
     parameter PKT_LEN          = 16)              // length of the packet
  (
     input                             rst_n,  
     // AXI-ST MINIMAL interface before Control Word Stripping
     input  [AXIS_TDATA_WIDTH-1:0]     cws_axi_str_tdata_in,
     input                             cws_axi_str_tvalid_in,
     output                            cws_axi_str_tready_out,
     // AXI-ST interface after Contorl Word Stripping
     output     [AXIS_TDATA_WIDTH-1:0] cws_axi_str_tdata_out ,
     output     [STRB_WIDTH-1:0]       cws_axi_str_tkeep_out ,
     output                            cws_axi_str_tlast_out ,
     output                            cws_axi_str_tvalid_out,
     input                             cws_axi_str_tready_in,  
     input                             axi_str_aclk,
     output reg [PKT_LEN-1:0]          cws_axi_str_tuser_out = 'd0
  );

localparam CNTRL_WORD_STRIP     = 3'b001, 
           READ_FIRST_DATA_WORD = 3'b010, 
           WAIT_FOR_EOP         = 3'b100;

wire                   first_data_beat_en;
wire                   cws_axi_str_tlast;
reg  [2:0]             fsm_state = CNTRL_WORD_STRIP;
reg  [15:0]            cntr_to_gen_rd_tlast = 'd0;
reg  [REM_WIDTH-1:0]   rd_strb_val = 'd0;
wire [STRB_WIDTH-1:0]  cws_axi_str_tkeep;
wire [STRB_WIDTH-1:0]  tkeep;

/***********************************************************************************************************
// State Machine on the read side of AXI FIFO, to generate rd_tvalid, cws_axi_str_tuser_outgth, rd_strb signals
// FSM does the following:
// 1. In the first state(CNTRL_WORD_STRIP), when ASYNC FIFO is not empty, it reads first word which is the CW. 
// 2. In the second state(READ_FIRST_DATA_WORD), it reads the second word, which is the first data beat of the
//    packet and makes it available with tvalid=1. If tlast also occurs in the same clock, which means that it 
//    is a single cycle packet,it goes back to the first state(CNTRL_WORD_STRIP), otherwise goes to WAIT_FOR_EOP
//    state.
// 3. In the third state(WAIT_FOR_EOP), it waits for End of packet and on finding EOP, it moves to the first
//    state.
// The first two steps above are irrespective of value of tready from application. Subsequent reads to the
// ASYNC-FIFO (till this packet is drained out completely based on the CW length) are based on tready assertion
// from user logic.
************************************************************************************************************/

always @(posedge axi_str_aclk)
begin
  if (~rst_n)
    fsm_state              <= CNTRL_WORD_STRIP;
  else
  begin
    case (fsm_state)

        CNTRL_WORD_STRIP:

              if (cws_axi_str_tvalid_in)
                fsm_state          <= READ_FIRST_DATA_WORD;
              else
                fsm_state          <= CNTRL_WORD_STRIP;

        READ_FIRST_DATA_WORD:  

              begin

                if(cws_axi_str_tvalid_in & cws_axi_str_tready_in)
                begin
                    if(cws_axi_str_tlast)
                        fsm_state  <= CNTRL_WORD_STRIP;
                    else
                        fsm_state  <= WAIT_FOR_EOP;
                end
                else
                   fsm_state       <= READ_FIRST_DATA_WORD;
              end

        WAIT_FOR_EOP: 

              begin
                if(cws_axi_str_tvalid_in & cws_axi_str_tready_in)
                begin
                    if (cws_axi_str_tlast)
                      fsm_state    <= CNTRL_WORD_STRIP;
                    else  
                      fsm_state    <= WAIT_FOR_EOP;
                end
                else
                      fsm_state    <= WAIT_FOR_EOP;
              end

        default: fsm_state  <= CNTRL_WORD_STRIP;          
      endcase
    end
  end

assign cws_axi_str_tvalid = (fsm_state == CNTRL_WORD_STRIP) ? 1'b0 : cws_axi_str_tvalid_in;
assign first_data_beat_en =  cws_axi_str_tvalid_in & (fsm_state == CNTRL_WORD_STRIP) ? 1'b1 : 1'b0;

always@(posedge axi_str_aclk)
if(first_data_beat_en)
begin
    cws_axi_str_tuser_out  <= cws_axi_str_tdata_in[PKT_LEN-1:0];
    rd_strb_val <= cws_axi_str_tdata_in[PKT_LEN+REM_WIDTH-1:PKT_LEN];
end

// Logic for generating tlast from packet length 

always@(posedge axi_str_aclk)
begin
if(~rst_n)
   cntr_to_gen_rd_tlast <= 'd0;
else if(first_data_beat_en)
begin
    if(cws_axi_str_tdata_in[PKT_LEN-1:0] <= STRB_WIDTH)  //Single cycle packet
       cntr_to_gen_rd_tlast <= 'd1;
    else
      if((cws_axi_str_tdata_in[PKT_LEN-1:0]%STRB_WIDTH) == 'd0)
          cntr_to_gen_rd_tlast <= (cws_axi_str_tdata_in[PKT_LEN-1:0]/STRB_WIDTH);
      else
          cntr_to_gen_rd_tlast <= (cws_axi_str_tdata_in[PKT_LEN-1:0]/STRB_WIDTH) + 'd1;
end
else if(cws_axi_str_tvalid & cws_axi_str_tready_in)
   cntr_to_gen_rd_tlast <= (cntr_to_gen_rd_tlast - 'd1);
end

assign cws_axi_str_tlast = (cntr_to_gen_rd_tlast == 'd1);

assign tkeep = (rd_strb_val == {REM_WIDTH{1'b0}}) ? {STRB_WIDTH{1'b1}} : (~({STRB_WIDTH{1'b1}} << rd_strb_val));
assign cws_axi_str_tkeep = cws_axi_str_tlast ? tkeep : {STRB_WIDTH{1'b1}};

assign cws_axi_str_tvalid_out = cws_axi_str_tvalid; 

assign cws_axi_str_tlast_out  = cws_axi_str_tlast; 
assign cws_axi_str_tkeep_out  = cws_axi_str_tkeep;

assign      cws_axi_str_tdata_out  = cws_axi_str_tdata_in;

assign cws_axi_str_tready_out = (first_data_beat_en | cws_axi_str_tready_in);

endmodule
