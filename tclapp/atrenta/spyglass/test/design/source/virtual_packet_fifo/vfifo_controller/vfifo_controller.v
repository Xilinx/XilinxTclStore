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

// Description of module:
// This module instantiates: 1. ingress_fifo
//                           2. egress_fifo
//                           3. address_manager

`timescale 1ps/1ps

module vfifo_controller # (
    parameter DWIDTH     = 32,
    parameter AWIDTH     = 32,
    parameter ISSUANCE_LEVEL = 2,
    parameter ID_WIDTH   = 4,
    parameter TXCNTWIDTH = 9,
    parameter RXCNTWIDTH = 9,
    parameter AXI_VFIFO_DATA_WIDTH = 64
    )  
    ( 
 
   input                   wr_clk, 
   input                   rd_clk,
   input                   mcb_clk,
   input                   rst_n,
   input                   wr_reset_n, 
   input                   rd_reset_n,
   input  [AWIDTH - 1:0]   start_addr,
   input  [AWIDTH - 1:0]   end_addr,
   input  [8:0]            wrburst_size,
   input  [8:0]            rdburst_size,
    
    // interface to AXI MM write address port
   output [ID_WIDTH-1:0]   p0_axi_awid,
   output [AWIDTH-1:0]     p0_axi_awaddr,
   output [7:0]            p0_axi_awlen,
   output [2:0]            p0_axi_awsize,
   output [1:0]            p0_axi_awburst,
   output [1:0]            p0_axi_awlock,
   output [3:0]            p0_axi_awcache,
   output [2:0]            p0_axi_awprot,
   output [3:0]            p0_axi_awqos,
   output                  p0_axi_awvalid,
   input                   p0_axi_awready,

   // interface to AXI MM read address port
   output [ID_WIDTH-1:0]   p0_axi_arid,
   output [AWIDTH-1:0]     p0_axi_araddr,
   output [7:0]            p0_axi_arlen,
   output [2:0]            p0_axi_arsize,
   output [1:0]            p0_axi_arburst,
   output [1:0]            p0_axi_arlock,
   output [3:0]            p0_axi_arcache,
   output [2:0]            p0_axi_arprot,
   output [3:0]            p0_axi_arqos,
   output                  p0_axi_arvalid,
   input                   p0_axi_arready,
   
   // interface to AXI MM write address response port
   input  [1:0]            p0_axi_bresp,
   input                   p0_axi_bvalid,
   output                  p0_axi_bready,

   // register interface-error status
   output                  p0_axi_wr_error,
   output                  p0_axi_rd_error,
    
   // AXI Async FIFO Interface
   input  [DWIDTH-1:0]     p0_axi_str_wr_tdata,
   input                   p0_axi_str_wr_tvalid,
   output                  p0_axi_str_wr_tready,
   
   // AXI MM Write Data Interface
   output                  p0_axi_wlast,                            
   output [AXI_VFIFO_DATA_WIDTH-1:0]     p0_axi_wdata,
   output                  p0_axi_wvalid,
   input                   p0_axi_wready,
   output [AXI_VFIFO_DATA_WIDTH/8-1:0]   p0_axi_wstrb,                            

   // AXI Async FIFO Interface
   output [DWIDTH-1:0]     p0_axi_str_rd_tdata,
   output                  p0_axi_str_rd_tvalid,
   input                   p0_axi_str_rd_tready,
   
   // AXI MM Read Data Interface
   input                   p0_axi_rlast,                           
   input  [AXI_VFIFO_DATA_WIDTH-1:0]     p0_axi_rdata,
   input                   p0_axi_rvalid,
   output                  p0_axi_rready,
   input  [AXI_VFIFO_DATA_WIDTH/8-1:0]   p0_axi_rstrb,            
   input  [1:0]            p0_axi_rresp,

   output [RXCNTWIDTH-1:0]  rd_data_count,
   output [TXCNTWIDTH-1:0]  wr_data_count,
   output reg               ddr3_fifo_empty
 
    );

// Internal signals
wire       wr_ready;
wire       rd_ready;
wire [8:0] WR_LEN;
wire [8:0] RD_LEN;
wire       rd_data_done;
wire       wr_empty;
wire       rd_full;
wire [TXCNTWIDTH-1:0] wr_count;
wire [RXCNTWIDTH-1:0] rd_count;
wire [1:0] RD_RRESP;
wire [8:0]            wr_burst_cnt;
wire [8:0]            rd_burst_cnt;
wire                  rd_subopt;
wire                  wr_subopt;
wire                  wr_issued;
wire                  wlast_done;
wire                  wr_reset_mcb_n;
wire                  rd_reset_mcb_n;
wire                  reset_to_use;
wire                  ddr3_fifo_empty_sync;
wire  [AWIDTH-1:0]    start_addr_sync;             
wire  [AWIDTH-1:0]    end_addr_sync;             
wire  [8:0]           wrburst_size_sync; 
wire  [8:0]           rdburst_size_sync; 

 // Use synchronizer to change signals to the MCB_CLK clock domain
 synchronizer_simple #(.DATA_WIDTH (1)) sync_to_user_clk_0
 (
   .data_in          (wr_reset_n),
   .new_clk          (mcb_clk),
   .data_out         (wr_reset_mcb_n)
 );

 synchronizer_simple #(.DATA_WIDTH (1)) sync_to_user_clk_1
 (
   .data_in          (rd_reset_n),
   .new_clk          (mcb_clk),
   .data_out         (rd_reset_mcb_n)
 );

 synchronizer_simple #(.DATA_WIDTH (1)) sync_to_user_clk_2
 (
   .data_in          (ddr3_fifo_empty_i),
   .new_clk          (rd_clk),
   .data_out         (ddr3_fifo_empty_sync)
 );

 synchronizer_simple #(.DATA_WIDTH (9)) sync_wrburst_to_user_clk_i
 (
   .data_in          (wrburst_size),
   .new_clk          (mcb_clk),
   .data_out         (wrburst_size_sync)
 );

 synchronizer_simple #(.DATA_WIDTH (9)) sync_rdburst_to_user_clk_i
 (
   .data_in          (rdburst_size),
   .new_clk          (mcb_clk),
   .data_out         (rdburst_size_sync)
 );


 synchronizer_simple #(.DATA_WIDTH (AWIDTH)) sync_strtaddr_to_user_clk_i
 (
   .data_in          (start_addr),
   .new_clk          (mcb_clk),
   .data_out         (start_addr_sync)
 );

 synchronizer_simple #(.DATA_WIDTH (AWIDTH)) sync_endaddr_to_user_clk_i
 (
   .data_in          (end_addr),
   .new_clk          (mcb_clk),
   .data_out         (end_addr_sync)
 );

assign reset_to_use = wr_reset_mcb_n & rd_reset_mcb_n & rst_n;

always @(posedge rd_clk)
  ddr3_fifo_empty <= ddr3_fifo_empty_sync & (rd_data_count==0);

ingress_fifo # (
    .DWIDTH             (DWIDTH),
    .ISSUANCE_LEVEL     (ISSUANCE_LEVEL),
    .AXI_VFIFO_DATA_WIDTH (AXI_VFIFO_DATA_WIDTH),
    .TXCNTWIDTH         (TXCNTWIDTH)
    )
    IGP (
   .wr_clk               (wr_clk),             
   .rd_clk               (mcb_clk),            
   .rst_n                (reset_to_use),                

   // AXI Async FIFO Interface
   .p0_axi_str_wr_tdata  (p0_axi_str_wr_tdata),
   .p0_axi_str_wr_tvalid (p0_axi_str_wr_tvalid),
   .p0_axi_str_wr_tready (p0_axi_str_wr_tready),
   
   // AXI Memory Mapped Interface
   .p0_axi_wlast         (p0_axi_wlast),                           
   .p0_axi_wdata         (p0_axi_wdata),
   .p0_axi_wvalid        (p0_axi_wvalid),
   .p0_axi_wready        (p0_axi_wready),
   .p0_axi_wstrb         (p0_axi_wstrb),             
   
   // Control & Address Generation logic Interface 
   .wr_ready             (wr_ready),
   .WR_LEN               (WR_LEN),
   .wr_empty             (wr_empty),
   .wr_count             (wr_count),
   .wr_burst_cnt         (wr_burst_cnt),
   .wlast_done           (wlast_done),
   .wr_issued            (wr_issued),
   .wr_subopt            (wr_subopt),
   .wr_data_count        (wr_data_count),
   .wrburst_size         (wrburst_size_sync));
   

egress_fifo # (
    .DWIDTH      (DWIDTH),
    .ISSUANCE_LEVEL (ISSUANCE_LEVEL),
    .AXI_VFIFO_DATA_WIDTH (AXI_VFIFO_DATA_WIDTH),
    .RXCNTWIDTH  (RXCNTWIDTH)
    )
    EGP (
   .wr_clk                  (mcb_clk),             
   .rd_clk                  (rd_clk),            
   .rst_n                   (reset_to_use),

   // AXI Async FIFO Interface
   .p0_axi_str_rd_tdata     (p0_axi_str_rd_tdata),
   .p0_axi_str_rd_tvalid    (p0_axi_str_rd_tvalid),
   .p0_axi_str_rd_tready    (p0_axi_str_rd_tready),
   
   // AXI Memory Mapped Interface
   .p0_axi_rlast            (p0_axi_rlast),                           
   .p0_axi_rdata            (p0_axi_rdata),
   .p0_axi_rvalid           (p0_axi_rvalid),
   .p0_axi_rready           (p0_axi_rready),
   .p0_axi_rstrb            (p0_axi_rstrb), 
   .p0_axi_rresp            (p0_axi_rresp),   
   
   // Control & Address Generation logic Interface 
   .rd_ready                (rd_ready),
   .RD_LEN                  (RD_LEN),
   .rd_full                 (rd_full),
   .rd_count                (rd_count),
   .rd_data_done            (rd_data_done),
   .RD_RRESP                (RD_RRESP),
   .rd_data_count           (rd_data_count),
   .rd_burst_cnt            (rd_burst_cnt),
   .rd_subopt               (rd_subopt),
   .rdburst_size            (rdburst_size_sync)
   );
    

address_manager # (
   .AWIDTH       (AWIDTH),
   .DWIDTH       (DWIDTH),
   .ISSUANCE_LEVEL (ISSUANCE_LEVEL),
   .AXI_VFIFO_DATA_WIDTH (AXI_VFIFO_DATA_WIDTH),
   .RXCNTWIDTH  (RXCNTWIDTH),
   .TXCNTWIDTH  (TXCNTWIDTH),
   .ID_WIDTH     (ID_WIDTH)
   
    )
    ADDR_MGR ( 
   .clk                 (mcb_clk),               
   .rst_n               (reset_to_use),              
   .start_addr          (start_addr_sync),   
   .end_addr            (end_addr_sync),  
   .wrburst_size        (wrburst_size_sync),
   .rdburst_size        (rdburst_size_sync),

   // interface to AXI MM write address port
   .p0_axi_awid         (p0_axi_awid),
   .p0_axi_awaddr       (p0_axi_awaddr),
   .p0_axi_awlen        (p0_axi_awlen),
   .p0_axi_awsize       (p0_axi_awsize),
   .p0_axi_awburst      (p0_axi_awburst),
   .p0_axi_awlock       (p0_axi_awlock),
   .p0_axi_awcache      (p0_axi_awcache),
   .p0_axi_awprot       (p0_axi_awprot),
   .p0_axi_awqos        (p0_axi_awqos),
   .p0_axi_awvalid      (p0_axi_awvalid),
   .p0_axi_awready      (p0_axi_awready),

   // interface to AXI MM read address port
   .p0_axi_arid         (p0_axi_arid),
   .p0_axi_araddr       (p0_axi_araddr),
   .p0_axi_arlen        (p0_axi_arlen),
   .p0_axi_arsize       (p0_axi_arsize),
   .p0_axi_arburst      (p0_axi_arburst),
   .p0_axi_arlock       (p0_axi_arlock),
   .p0_axi_arcache      (p0_axi_arcache),
   .p0_axi_arprot       (p0_axi_arprot),
   .p0_axi_arqos        (p0_axi_arqos),
   .p0_axi_arvalid      (p0_axi_arvalid),
   .p0_axi_arready      (p0_axi_arready),
   
   // interface to AXI MM write address response port
   .p0_axi_bresp        (p0_axi_bresp),
   .p0_axi_bvalid       (p0_axi_bvalid),
   .p0_axi_bready       (p0_axi_bready),
  
   // register interface-error status
   .p0_axi_wr_error     (p0_axi_wr_error),
   .p0_axi_rd_error     (p0_axi_rd_error),

   // interface to write data port
   .wr_ready            (wr_ready),
   .WR_LEN              (WR_LEN),
   .wr_empty            (wr_empty),
   .wr_count            (wr_count),
   .wr_subopt           (wr_subopt),
   .rd_subopt           (rd_subopt),

   // interface to read data port
   .rd_ready            (rd_ready),
   .RD_LEN              (RD_LEN),
   .rd_full             (rd_full),
   .rd_count            (rd_count),
   .rd_data_done        (rd_data_done),
   .RD_RRESP            (RD_RRESP),
   .wlast_done          (wlast_done),
   .wr_burst_cnt        (wr_burst_cnt),
   .rd_burst_cnt        (rd_burst_cnt),
   .wr_issued           (wr_issued),
   .ddr3_fifo_empty     (ddr3_fifo_empty_i)
    );
    
endmodule 

