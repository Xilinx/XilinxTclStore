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
`timescale 1ps / 1ps
(* CORE_GENERATION_INFO = "k7_pcie_dma_ddr3_base,k7_pcie_dma_ddr3_base_trd_v1_6,{virtual_packet_fifo=2013.2}" *)
module virtual_packet_fifo_wrapper # (
    parameter AXIS_TDATA_WIDTH    = 64,
    parameter AXIS_TKEEP_WIDTH    = 8,
    parameter NUM_PORTS           = 4,
    parameter CNTWIDTH            = 12
  )
  (
`ifdef USE_DDR3_FIFO
   // DDR3 ports
    input                                 sys_clk_p,
    input                                 sys_clk_n,

    output [13:0]                         ddr_addr,             
    output [2:0]                          ddr_ba,               
    output                                ddr_cas_n,            
    output                                ddr_ck_p,               
    output                                ddr_ck_n,             
    output                                ddr_cke,              
    output                                ddr_cs_n,             
    output [7:0]                          ddr_dm,               
    inout  [63:0]                         ddr_dq,               
    inout  [7:0]                          ddr_dqs_p,              
    inout  [7:0]                          ddr_dqs_n,            
    output                                ddr_odt,              
    output                                ddr_ras_n,            
    output                                ddr_reset_n,          
    output                                ddr_we_n,             
    inout                                 sda,
    output                                scl,
    output                                calib_done,
    
    output [NUM_PORTS-1:0]                ddr3_fifo_empty,
    input                                 axi_ic_mig_shim_rst_n,
    input  [31:0]                         start_addr_p0,
    input  [31:0]                         end_addr_p0,
    input  [8:0]                          wr_burst_size_p0,
    input  [8:0]                          rd_burst_size_p0,
    input  [31:0]                         start_addr_p1,
    input  [31:0]                         end_addr_p1,
    input  [8:0]                          wr_burst_size_p1,
    input  [8:0]                          rd_burst_size_p1,
    input  [31:0]                         start_addr_p2,
    input  [31:0]                         end_addr_p2,
    input  [8:0]                          wr_burst_size_p2,
    input  [8:0]                          rd_burst_size_p2,
    input  [31:0]                         start_addr_p3,
    input  [31:0]                         end_addr_p3,
    input  [8:0]                          wr_burst_size_p3,
    input  [8:0]                          rd_burst_size_p3,
`endif    

    input                                 sys_reset,   
    input                                 user_reset,   
    input                                 user_clk,   
    output                                axi_str_tx_rd0_tlast,              
    output [AXIS_TDATA_WIDTH-1:0]         axi_str_tx_rd0_tdata,             
    output [AXIS_TKEEP_WIDTH-1:0]         axi_str_tx_rd0_tkeep,
    output                                axi_str_tx_rd0_tvalid,          
    input                                 axi_str_tx_rd0_tready,          

    input                                 axi_str_rx_rd0_tlast,              
    input   [AXIS_TDATA_WIDTH-1:0]        axi_str_rx_rd0_tdata,             
    input   [AXIS_TKEEP_WIDTH-1:0]        axi_str_rx_rd0_tkeep,
    input                                 axi_str_rx_rd0_tvalid,          
    output                                axi_str_rx_rd0_tready,          

    output                                axi_str_tx_rd1_tlast,              
    output  [AXIS_TDATA_WIDTH-1:0]        axi_str_tx_rd1_tdata,             
    output  [AXIS_TKEEP_WIDTH-1:0]        axi_str_tx_rd1_tkeep,
    output                                axi_str_tx_rd1_tvalid,          
    input                                 axi_str_tx_rd1_tready,          

    input                                 axi_str_rx_rd1_tlast,              
    input    [AXIS_TDATA_WIDTH-1:0]       axi_str_rx_rd1_tdata,             
    input    [AXIS_TKEEP_WIDTH-1:0]       axi_str_rx_rd1_tkeep,
    input                                 axi_str_rx_rd1_tvalid,          
    output                                axi_str_rx_rd1_tready,          

    input                                 axi_str_s2c0_tlast,              
    input  [AXIS_TDATA_WIDTH-1:0]         axi_str_s2c0_tdata,             
    input  [AXIS_TKEEP_WIDTH-1:0]         axi_str_s2c0_tkeep,
    input                                 axi_str_s2c0_tvalid,          
    output                                axi_str_s2c0_tready,          

    output                                axi_str_c2s0_tlast,              
    output [AXIS_TDATA_WIDTH-1:0]         axi_str_c2s0_tdata,             
    output [AXIS_TKEEP_WIDTH-1:0]         axi_str_c2s0_tkeep,
    output                                axi_str_c2s0_tvalid,          
    input                                 axi_str_c2s0_tready,          

    input                                 axi_str_s2c1_tlast,              
    input  [AXIS_TDATA_WIDTH-1:0]         axi_str_s2c1_tdata,             
    input  [AXIS_TKEEP_WIDTH-1:0]         axi_str_s2c1_tkeep,
    input                                 axi_str_s2c1_tvalid,          
    output                                axi_str_s2c1_tready,          

    output                                axi_str_c2s1_tlast,              
    output [AXIS_TDATA_WIDTH-1:0]         axi_str_c2s1_tdata,             
    output [AXIS_TKEEP_WIDTH-1:0]         axi_str_c2s1_tkeep,
    output                                axi_str_c2s1_tvalid,          
    input                                 axi_str_c2s1_tready,          

    input                                 axi_str_c2s0_areset_n,          
    input                                 axi_str_s2c0_areset_n,          
    input                                 axi_str_c2s1_areset_n,          
    input                                 axi_str_s2c1_areset_n,          

    output [CNTWIDTH-1:0]                 tx_rd0_rd_rdy, 
    output [CNTWIDTH-1:0]                 c2s0_rd_rdy,   
    output [CNTWIDTH-1:0]                 tx_rd1_rd_rdy, 
    output [CNTWIDTH-1:0]                 c2s1_rd_rdy,   

    output [CNTWIDTH-1:0]                 s2c0_wr_rdy,   
    output [CNTWIDTH-1:0]                 rx_rd0_wr_rdy, 
    output [CNTWIDTH-1:0]                 s2c1_wr_rdy,   
    output [CNTWIDTH-1:0]                 rx_rd1_wr_rdy,

    input  [15:0]                         pkt_len0,
    input  [15:0]                         pkt_len1
    

  );



  // ----------------
  // -- Parameters --
  // ----------------
  
  localparam  AXI_VFIFO_DATA_WIDTH    = 64;
  localparam  AXI_MIG_DATA_WIDTH      = 256;

  localparam  DWIDTH = AXIS_TDATA_WIDTH;
  localparam  AWIDTH = 32;

  localparam  ID_WIDTH  = 2;
  localparam  LED_CTR_WIDTH   = 26;
  localparam  ISSUANCE_LEVEL = 2;

// -------------------
// -- Local Signals --
// -------------------

`ifdef USE_DDR3_FIFO
wire                                    calib_done_200Mhz;
wire                                    mcb_clk;
wire                                    mcb_rst;
`endif

wire [NUM_PORTS-1:0]                    px_axi_str_wr_tlast;
wire [(DWIDTH*NUM_PORTS)-1:0]           px_axi_str_wr_tdata;
wire [NUM_PORTS-1:0]                    px_axi_str_wr_tvalid;
wire [(DWIDTH/8*NUM_PORTS)-1:0]         px_axi_str_wr_tkeep;
wire [NUM_PORTS-1:0]                    px_axi_str_wr_tready;
wire [NUM_PORTS-1:0]                    px_axi_str_rd_tlast;
wire [(DWIDTH*NUM_PORTS)-1:0]           px_axi_str_rd_tdata;
wire [NUM_PORTS-1:0]                    px_axi_str_rd_tvalid;
wire [(DWIDTH/8*NUM_PORTS)-1:0]         px_axi_str_rd_tkeep;
wire [NUM_PORTS-1:0]                    px_axi_str_rd_tready;
wire [(NUM_PORTS*8)-1:0]                px_error_count;
wire [(NUM_PORTS*16)-1:0]               px_axi_str_wr_len;
wire [(NUM_PORTS*16)-1:0]               px_axi_str_rd_len;

wire [(NUM_PORTS*CNTWIDTH)-1:0]         px_axi_str_rd_cnt;
wire [(NUM_PORTS*CNTWIDTH)-1:0]         px_axi_str_wr_cnt;

wire [NUM_PORTS-1:0]                    user_reset_n;
wire [NUM_PORTS-1:0]                    user_reset_reg_n;

assign px_axi_str_wr_tlast   = {axi_str_rx_rd1_tlast,  axi_str_s2c1_tlast,  axi_str_rx_rd0_tlast,  axi_str_s2c0_tlast};
assign px_axi_str_wr_tdata   = {axi_str_rx_rd1_tdata,  axi_str_s2c1_tdata,  axi_str_rx_rd0_tdata,  axi_str_s2c0_tdata};
assign px_axi_str_wr_tvalid  = {axi_str_rx_rd1_tvalid, axi_str_s2c1_tvalid, axi_str_rx_rd0_tvalid, axi_str_s2c0_tvalid};
assign px_axi_str_wr_tkeep   = {axi_str_rx_rd1_tkeep,  axi_str_s2c1_tkeep,  axi_str_rx_rd0_tkeep,  axi_str_s2c0_tkeep};

assign px_axi_str_rd_tready  = {axi_str_c2s1_tready, axi_str_tx_rd1_tready, axi_str_c2s0_tready, axi_str_tx_rd0_tready};

assign px_axi_str_wr_len     = {pkt_len1, pkt_len1, pkt_len0, pkt_len0};

assign axi_str_s2c0_tready   = px_axi_str_wr_tready[0];
assign axi_str_rx_rd0_tready = px_axi_str_wr_tready[1];
assign axi_str_s2c1_tready   = px_axi_str_wr_tready[2];
assign axi_str_rx_rd1_tready = px_axi_str_wr_tready[3];

assign axi_str_tx_rd0_tlast  = px_axi_str_rd_tlast[0];
assign axi_str_c2s0_tlast    = px_axi_str_rd_tlast[1];
assign axi_str_tx_rd1_tlast  = px_axi_str_rd_tlast[2];
assign axi_str_c2s1_tlast    = px_axi_str_rd_tlast[3];

assign axi_str_tx_rd0_tdata  = px_axi_str_rd_tdata[AXIS_TDATA_WIDTH*1-1:AXIS_TDATA_WIDTH*0];
assign axi_str_c2s0_tdata    = px_axi_str_rd_tdata[AXIS_TDATA_WIDTH*2-1:AXIS_TDATA_WIDTH*1];
assign axi_str_tx_rd1_tdata  = px_axi_str_rd_tdata[AXIS_TDATA_WIDTH*3-1:AXIS_TDATA_WIDTH*2];
assign axi_str_c2s1_tdata    = px_axi_str_rd_tdata[AXIS_TDATA_WIDTH*4-1:AXIS_TDATA_WIDTH*3];

assign axi_str_tx_rd0_tvalid = px_axi_str_rd_tvalid[0];
assign axi_str_c2s0_tvalid   = px_axi_str_rd_tvalid[1];
assign axi_str_tx_rd1_tvalid = px_axi_str_rd_tvalid[2];
assign axi_str_c2s1_tvalid   = px_axi_str_rd_tvalid[3];

assign axi_str_tx_rd0_tkeep  = px_axi_str_rd_tkeep[AXIS_TKEEP_WIDTH*1-1:AXIS_TKEEP_WIDTH*0];
assign axi_str_c2s0_tkeep    = px_axi_str_rd_tkeep[AXIS_TKEEP_WIDTH*2-1:AXIS_TKEEP_WIDTH*1];
assign axi_str_tx_rd1_tkeep  = px_axi_str_rd_tkeep[AXIS_TKEEP_WIDTH*3-1:AXIS_TKEEP_WIDTH*2];
assign axi_str_c2s1_tkeep    = px_axi_str_rd_tkeep[AXIS_TKEEP_WIDTH*4-1:AXIS_TKEEP_WIDTH*3];

assign tx_rd0_rd_rdy         = px_axi_str_rd_cnt[CNTWIDTH*1-1:CNTWIDTH*0];
assign c2s0_rd_rdy           = px_axi_str_rd_cnt[CNTWIDTH*2-1:CNTWIDTH*1];
assign tx_rd1_rd_rdy         = px_axi_str_rd_cnt[CNTWIDTH*3-1:CNTWIDTH*2];
assign c2s1_rd_rdy           = px_axi_str_rd_cnt[CNTWIDTH*4-1:CNTWIDTH*3];
                             

assign s2c0_wr_rdy           = (2**(CNTWIDTH-1)) - px_axi_str_wr_cnt[CNTWIDTH*1-1:CNTWIDTH*0];
assign rx_rd0_wr_rdy         = (2**(CNTWIDTH-1)) - px_axi_str_wr_cnt[CNTWIDTH*2-1:CNTWIDTH*1];
assign s2c1_wr_rdy           = (2**(CNTWIDTH-1)) - px_axi_str_wr_cnt[CNTWIDTH*3-1:CNTWIDTH*2];
assign rx_rd1_wr_rdy         = (2**(CNTWIDTH-1)) - px_axi_str_wr_cnt[CNTWIDTH*4-1:CNTWIDTH*3];


`ifdef VERIF
  virtual_packet_fifo_verif #(
`else
  virtual_packet_fifo #(
`endif
      .NUM_PORTS                            (NUM_PORTS          ),
      .AXIS_TDATA_WIDTH                     (AXIS_TDATA_WIDTH   ),
      .AXI_MIG_DATA_WIDTH                   (AXI_MIG_DATA_WIDTH),
      .AWIDTH                               (AWIDTH),    
      .CNTWIDTH                             (CNTWIDTH),
      .DWIDTH                               (DWIDTH),
      .ISSUANCE_LEVEL                       (ISSUANCE_LEVEL),
      .ID_WIDTH                             (ID_WIDTH)
  ) mp_pfifo_inst (
`ifdef USE_DDR3_FIFO
      .calib_done                           (calib_done_200Mhz     ),
      .sys_clk_p                            (sys_clk_p             ),
      .sys_clk_n                            (sys_clk_n             ),
      .mcb_clk                              (mcb_clk               ),
      .mcb_rst                              (mcb_rst               ),
      .ddr_addr                             (ddr_addr              ),
      .ddr_ba                               (ddr_ba                ),
      .ddr_cas_n                            (ddr_cas_n             ),
      .ddr_ck_p                             (ddr_ck_p              ),
      .ddr_ck_n                             (ddr_ck_n              ),
      .ddr_cke                              (ddr_cke               ),
      .ddr_cs_n                             (ddr_cs_n              ),
      .ddr_dm                               (ddr_dm                ),
      .ddr_odt                              (ddr_odt               ),
      .ddr_ras_n                            (ddr_ras_n             ),
      .ddr_reset_n                          (ddr_reset_n           ),
      .ddr_we_n                             (ddr_we_n              ),
      .ddr_dq                               (ddr_dq                ),
      .ddr_dqs_p                            (ddr_dqs_p             ),
      .ddr_dqs_n                            (ddr_dqs_n             ),
      .sda                                  (sda                   ),
      .scl                                  (scl                   ),

  `ifdef SIMULATION
     .start_addr                            ({32'h0000_6000,32'h0000_4000,32'h0000_2000,32'h0000_0000}),
     .end_addr                              ({32'h0000_7000,32'h0000_5000,32'h0000_3000,32'h0000_1000}),
  `else
     .start_addr                            ({start_addr_p3,start_addr_p2,start_addr_p1,start_addr_p0}),
     .end_addr                              ({end_addr_p3,end_addr_p2,end_addr_p1,end_addr_p0}),
  `endif 

     .wrburst_size                          ({wr_burst_size_p3, wr_burst_size_p2, wr_burst_size_p1, wr_burst_size_p0}),
     .rdburst_size                          ({rd_burst_size_p3, rd_burst_size_p2, rd_burst_size_p1, rd_burst_size_p0}),
     
`endif     
   // AXI streaming Interface
     .axi_str_wr_tlast                      (px_axi_str_wr_tlast    ),
     .axi_str_wr_tdata                      (px_axi_str_wr_tdata    ),
     .axi_str_wr_tvalid                     (px_axi_str_wr_tvalid   ),
     .axi_str_wr_tready                     (px_axi_str_wr_tready   ),
     .axi_str_wr_tkeep                      (px_axi_str_wr_tkeep    ),
     .axi_str_wr_tuser                      (px_axi_str_wr_len      ), 
     .axi_str_wr_aclk                       ({NUM_PORTS{user_clk}}  ),     
     .wr_reset_n                            (user_reset_n),
     .vf_wr_data_cnt                        (px_axi_str_wr_cnt      ),
   // AXI streaming Interface
     .axi_str_rd_tlast                      (px_axi_str_rd_tlast    ),
     .axi_str_rd_tdata                      (px_axi_str_rd_tdata    ),
     .axi_str_rd_tvalid                     (px_axi_str_rd_tvalid   ),
     .axi_str_rd_tready                     (px_axi_str_rd_tready   ),
     .axi_str_rd_tkeep                      (px_axi_str_rd_tkeep    ),
     .axi_str_rd_tuser                      (px_axi_str_rd_len      ),
     .axi_str_rd_aclk                       ({NUM_PORTS{user_clk}}  ),     
     .rd_reset_n                            (user_reset_n),
     .vf_rd_data_cnt                        (px_axi_str_rd_cnt      ),
     .ddr3_fifo_empty                       (ddr3_fifo_empty        ),

 // This reset will reset the axi interconnect and axi interface of the MIG when the 
 // s2c and c2s dma engines are reset by software. We assume that the software
 // will verify all the packets are received before applying a reset (make remove)
     .axi_ic_mig_shim_rst_n                 (axi_ic_mig_shim_rst_n  ),
     .user_reset                            (sys_reset              )
    );  


  //- Reset registration for fan-out improvement
  genvar i;
  generate
    begin: reset_gen
      for (i=0; i<NUM_PORTS; i=i+1)
      begin
        synchronizer_simple #(.DATA_WIDTH(1)) register_user_reset
        (
          .data_in  (~user_reset),
          .new_clk  (user_clk),
          .data_out (user_reset_reg_n[i])
        );
      end
    end
  endgenerate  

assign user_reset_n[0] =  user_reset_reg_n[0] & axi_str_s2c0_areset_n;
assign user_reset_n[1] =  user_reset_reg_n[1] & axi_str_c2s0_areset_n;
assign user_reset_n[2] =  user_reset_reg_n[2] & axi_str_s2c1_areset_n;
assign user_reset_n[3] =  user_reset_reg_n[3] & axi_str_c2s1_areset_n;


 // Use synchronizer to change signals to the 250 MHz clock domain 
 synchronizer_simple #(.DATA_WIDTH (1)) sync_to_user_clk
 (
   .data_in          (calib_done_200Mhz),
   .new_clk          (user_clk),
   .data_out         (calib_done)
 );

endmodule

