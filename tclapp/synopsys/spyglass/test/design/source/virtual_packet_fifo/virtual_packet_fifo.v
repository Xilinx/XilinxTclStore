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

module virtual_packet_fifo #(
  parameter AXIS_TDATA_WIDTH          = 128,
  parameter AXI_MIG_DATA_WIDTH        = 512,
  parameter AWIDTH                    = 32,
  parameter DWIDTH                    = AXIS_TDATA_WIDTH,
  parameter NUM_PORTS                 = 4,
  parameter ISSUANCE_LEVEL            = 2,
  parameter ID_WIDTH                  = 2,
  parameter CNTWIDTH                  = 11
) (  
`ifdef USE_DDR3_FIFO
    // DDR3 ports
`ifdef USE_7SERIES    
    output [13:0]                  ddr_addr,             
`else
    output [12:0]                  ddr_addr,             
`endif
    output                         calib_done,
    input                          sys_clk_p,
    input                          sys_clk_n,

    output [2:0]                   ddr_ba,               
    output                         ddr_cas_n,            
    output                         ddr_ck_p,               
    output                         ddr_ck_n,             
    output                         ddr_cke,              
    output                         ddr_cs_n,             
    output [7:0]                   ddr_dm,               
    inout  [63:0]                  ddr_dq,               
    inout  [7:0]                   ddr_dqs_p,              
    inout  [7:0]                   ddr_dqs_n,            
    output                         ddr_odt,              
    output                         ddr_ras_n,            
    output                         ddr_reset_n,          
    output                         ddr_we_n,             
    inout                          sda,
    output                         scl,
    
      //- Control ports
   input   [(AWIDTH*NUM_PORTS)-1:0] start_addr,
   input   [(AWIDTH*NUM_PORTS)-1:0] end_addr,
   input   [(9*NUM_PORTS)-1:0]      wrburst_size,
   input   [(9*NUM_PORTS)-1:0]      rdburst_size,
   output                           mcb_clk, 
   output                           mcb_rst,
`else
    input sys_clk,
`endif    
   // AXI streaming Interface for Write port 
   input  [NUM_PORTS-1:0]              axi_str_wr_tlast,
   input  [(AXIS_TDATA_WIDTH*NUM_PORTS)-1:0]     axi_str_wr_tdata,
   input  [NUM_PORTS-1:0]              axi_str_wr_tvalid,
   input  [(AXIS_TDATA_WIDTH/8*NUM_PORTS)-1:0]  axi_str_wr_tkeep,
   input  [(NUM_PORTS * 16)-1:0]       axi_str_wr_tuser,
   output [NUM_PORTS-1:0]              axi_str_wr_tready,
   input  [NUM_PORTS-1:0]              axi_str_wr_aclk, 

   // AXI streaming Interface for Read port 
   output [NUM_PORTS-1:0]              axi_str_rd_tlast,
   output [(DWIDTH*NUM_PORTS)-1:0]     axi_str_rd_tdata,
   output [NUM_PORTS-1:0]              axi_str_rd_tvalid,
   output [(DWIDTH/8*NUM_PORTS)-1:0]   axi_str_rd_tkeep,
   input  [NUM_PORTS-1:0]              axi_str_rd_tready,
   input  [NUM_PORTS-1:0]              axi_str_rd_aclk, 
   output [(CNTWIDTH*NUM_PORTS)-1:0]   vf_rd_data_cnt,
   output [(CNTWIDTH*NUM_PORTS)-1:0]   vf_wr_data_cnt,
   output [(16*NUM_PORTS)-1:0]         axi_str_rd_tuser,
   output [NUM_PORTS-1:0]              ddr3_fifo_empty,
    
   input  [NUM_PORTS-1:0]              wr_reset_n, 
   input  [NUM_PORTS-1:0]              rd_reset_n, 
   input                               axi_ic_mig_shim_rst_n, 
   input                               user_reset

  );



  // ----------------
  // -- Parameters --
  // ----------------
  
  localparam  AXI_VFIFO_DATA_WIDTH    = AXIS_TDATA_WIDTH;


wire [(4 * NUM_PORTS)-1:0]                              axi_awid;
wire [(32 * NUM_PORTS)-1:0]                             axi_awaddr;
wire [(8 * NUM_PORTS)-1:0]                              axi_awlen;
wire [(3 * NUM_PORTS)-1:0]                              axi_awsize;
wire [(2 * NUM_PORTS)-1:0]                              axi_awburst;
wire [(2 * NUM_PORTS)-1:0]                              axi_awlock;
wire [(4 * NUM_PORTS)-1:0]                              axi_awcache;
wire [(3 * NUM_PORTS)-1:0]                              axi_awprot;
wire [(4 * NUM_PORTS)-1:0]                              axi_awqos;
wire [NUM_PORTS-1:0]                                    axi_awvalid;
wire [NUM_PORTS-1:0]                                    axi_awready;
wire [(AXI_VFIFO_DATA_WIDTH * NUM_PORTS)-1:0]           axi_wdata;
wire [((AXI_VFIFO_DATA_WIDTH/8) * NUM_PORTS)-1:0]       axi_wstrb;
wire [NUM_PORTS-1:0]                                    axi_wlast;
wire [NUM_PORTS-1:0]                                    axi_wvalid;
wire [NUM_PORTS-1:0]                                    axi_wready;
wire [(4 * NUM_PORTS)-1:0]                              axi_bid;
wire [(2 * NUM_PORTS)-1:0]                              axi_bresp;
wire [NUM_PORTS-1:0]                                    axi_bvalid;
wire [NUM_PORTS-1:0]                                    axi_bready;
wire [(4 * NUM_PORTS)-1:0]                              axi_arid;
wire [(32 * NUM_PORTS)-1:0]                             axi_araddr;
wire [(8 * NUM_PORTS)-1:0]                              axi_arlen;
wire [(3 * NUM_PORTS)-1:0]                              axi_arsize;
wire [(2 * NUM_PORTS)-1:0]                              axi_arburst;
wire [(2 * NUM_PORTS)-1:0]                              axi_arlock;
wire [(4 * NUM_PORTS)-1:0]                              axi_arcache;
wire [(3 * NUM_PORTS)-1:0]                              axi_arprot;
wire [(4 * NUM_PORTS)-1:0]                              axi_arqos;
wire [NUM_PORTS-1:0]                                    axi_arvalid;
wire [NUM_PORTS-1:0]                                    axi_arready;

wire [(4 * NUM_PORTS)-1:0]                              axi_rid;
wire [(AXI_VFIFO_DATA_WIDTH * NUM_PORTS)-1:0]           axi_rdata;
wire [(AXI_VFIFO_DATA_WIDTH/8 * NUM_PORTS)-1:0]         axi_rstrb;
wire [(2 * NUM_PORTS)-1:0]                              axi_rresp;
wire [NUM_PORTS-1:0]                                    axi_rlast;
wire [NUM_PORTS-1:0]                                    axi_rvalid;
wire [NUM_PORTS-1:0]                                    axi_rready;

wire [ID_WIDTH-1:0] px_awid [NUM_PORTS-1:0];
wire [AWIDTH-1:0]   px_awaddr [NUM_PORTS-1:0];
wire [7:0]          px_awlen [NUM_PORTS-1:0];
wire [2:0]          px_awsize [NUM_PORTS-1:0];
wire [1:0]          px_awburst [NUM_PORTS-1:0];
wire [1:0]          px_awlock [NUM_PORTS-1:0];
wire [3:0]          px_awcache [NUM_PORTS-1:0];
wire [2:0]          px_awprot [NUM_PORTS-1:0];
wire [3:0]          px_awqos [NUM_PORTS-1:0];
wire [AXI_VFIFO_DATA_WIDTH-1:0]   px_wdata [NUM_PORTS-1:0];
wire [(AXI_VFIFO_DATA_WIDTH/8)-1:0] px_wstrb [NUM_PORTS-1:0];
wire [ID_WIDTH-1:0] px_bid [NUM_PORTS-1:0];
wire [1:0]          px_bresp [NUM_PORTS-1:0];
wire [ID_WIDTH-1:0] px_arid [NUM_PORTS-1:0];
wire [AWIDTH-1:0]   px_araddr [NUM_PORTS-1:0];
wire [7:0]          px_arlen [NUM_PORTS-1:0];
wire [2:0]          px_arsize [NUM_PORTS-1:0];
wire [1:0]          px_arburst [NUM_PORTS-1:0];
wire [1:0]          px_arlock [NUM_PORTS-1:0];
wire [3:0]          px_arcache [NUM_PORTS-1:0];
wire [2:0]          px_arprot [NUM_PORTS-1:0];
wire [3:0]          px_arqos [NUM_PORTS-1:0];
wire [(AXI_VFIFO_DATA_WIDTH/8)-1:0] px_rstrb [NUM_PORTS-1:0];
wire [3:0]          px_rid [NUM_PORTS-1:0];
wire [AXI_VFIFO_DATA_WIDTH-1:0]   px_rdata [NUM_PORTS-1:0];
wire [1:0]          px_rresp [NUM_PORTS-1:0];

wire [AWIDTH-1:0]   px_start_addr [NUM_PORTS-1:0];
wire [AWIDTH-1:0]   px_end_addr [NUM_PORTS-1:0];
wire [8:0]          px_wrburst_size [NUM_PORTS-1:0];
wire [8:0]          px_rdburst_size [NUM_PORTS-1:0];

wire [CNTWIDTH-1:0] px_vf_rd_data_cnt [NUM_PORTS-1:0];
wire [CNTWIDTH-1:0] px_vf_wr_data_cnt [NUM_PORTS-1:0];
wire [15:0]         px_rd_tuser [NUM_PORTS-1:0];
wire [AXIS_TDATA_WIDTH-1:0]   px_str_rd_tdata [NUM_PORTS-1:0];
wire [(AXIS_TDATA_WIDTH/8)-1:0]   px_str_rd_tkeep [NUM_PORTS-1:0];
wire [AXIS_TDATA_WIDTH-1:0]   px_str_wr_tdata [NUM_PORTS-1:0];
wire [15:0]   px_axi_str_wr_tuser [NUM_PORTS-1:0];
wire [(AXIS_TDATA_WIDTH/8)-1:0]   px_str_wr_tkeep [NUM_PORTS-1:0];
wire axi_ic_mig_shim_rst_n_sync;


  /*
   *  Packetized Virtual FIFO Controller instances based on NUM_PORTS
   *  parameter
   */ 

genvar ii;
genvar jj;
genvar i;


generate
  begin: assign_output
    for (ii = 0; ii<NUM_PORTS; ii=ii+1)
    begin
  
`ifdef USE_DDR3_FIFO  
    assign axi_awid[((ID_WIDTH*ii)+(ID_WIDTH-1)) : ID_WIDTH*ii]  = px_awid[ii];
    assign axi_awaddr[((AWIDTH*ii)+(AWIDTH-1)) : AWIDTH*ii]      = px_awaddr[ii];
    assign axi_awlen[((8*ii)+7) : 8*ii]                          = px_awlen[ii];
    assign axi_awsize[((3*ii)+2) : 3*ii]                         = px_awsize[ii];
    assign axi_awburst[((2*ii)+1) : 2*ii]                        = px_awburst[ii];
    assign axi_awlock[((2*ii)+1) : 2*ii]                         = px_awlock[ii];
    assign axi_awcache[((4*ii)+3) : 4*ii]                        = px_awcache[ii];
    assign axi_awprot[((3*ii)+2) : 3*ii]                         = px_awprot[ii];
    assign axi_awqos[((4*ii)+3) : 4*ii]                          = px_awqos[ii];
    assign axi_arid[((ID_WIDTH*ii)+(ID_WIDTH-1)) : ID_WIDTH*ii]  = px_arid[ii];
    assign axi_araddr[((AWIDTH*ii)+(AWIDTH-1)) : AWIDTH*ii]      = px_araddr[ii];
    assign axi_arlen[((8*ii)+7) : 8*ii]                          = px_arlen[ii];
    assign axi_arsize[((3*ii)+2) : 3*ii]                         = px_arsize[ii];
    assign axi_arburst[((2*ii)+1) : 2*ii]                        = px_arburst[ii];
    assign axi_arlock[((2*ii)+1) : 2*ii]                         = px_arlock[ii];
    assign axi_arcache[((4*ii)+3) : 4*ii]                        = px_arcache[ii];
    assign axi_arprot[((3*ii)+2) : 3*ii]                         = px_arprot[ii];
    assign axi_arqos[((4*ii)+3) : 4*ii]                          = px_arqos[ii];
    assign axi_wdata[((AXI_VFIFO_DATA_WIDTH*ii)+(AXI_VFIFO_DATA_WIDTH-1)) : AXI_VFIFO_DATA_WIDTH*ii]       = px_wdata[ii];
    assign axi_wstrb[((AXI_VFIFO_DATA_WIDTH/8*ii)+(AXI_VFIFO_DATA_WIDTH/8-1)) : AXI_VFIFO_DATA_WIDTH/8*ii] = px_wstrb[ii];
`endif

    assign axi_str_rd_tdata[((AXIS_TDATA_WIDTH*ii)+(AXIS_TDATA_WIDTH-1)) : AXIS_TDATA_WIDTH*ii] = px_str_rd_tdata[ii];
    assign axi_str_rd_tkeep[(((AXIS_TDATA_WIDTH/8)*ii)+((AXIS_TDATA_WIDTH/8)-1)) : (AXIS_TDATA_WIDTH/8)*ii] = px_str_rd_tkeep[ii];

      //-Since first word is read automatically, increment data cnt
    assign vf_rd_data_cnt[((CNTWIDTH*ii) + (CNTWIDTH-1)) : (CNTWIDTH*ii)] = px_vf_rd_data_cnt[ii];
    assign vf_wr_data_cnt[((CNTWIDTH*ii) + (CNTWIDTH-1)) : (CNTWIDTH*ii)] = px_vf_wr_data_cnt[ii];

    assign axi_str_rd_tuser[((16*ii)+(16-1)):(16*ii)] = px_rd_tuser[ii];
    end
  end
endgenerate

generate
  begin: assign_input
    for (jj=0; jj<NUM_PORTS; jj=jj+1)
    begin
`ifdef USE_DDR3_FIFO    
    assign px_bid[jj]          = axi_bid[((ID_WIDTH*jj)+(ID_WIDTH-1)) : ID_WIDTH*jj];
    assign px_bresp[jj]        = axi_bresp[((2*jj)+1) : 2*jj];
    assign px_rdata[jj]        = axi_rdata[((AXI_VFIFO_DATA_WIDTH*jj)+(AXI_VFIFO_DATA_WIDTH-1)) : AXI_VFIFO_DATA_WIDTH*jj];
//    assign px_rstrb[jj]        = axi_rstrb[((AXI_MIG_DATA_WIDTH/8*jj)+(AXI_MIG_DATA_WIDTH/8-1)) : AXI_MIG_DATA_WIDTH/8*jj];
    assign px_rstrb[jj]        = ({(AXI_VFIFO_DATA_WIDTH/8){1'b1}});
    assign px_rresp[jj]        = axi_rresp[((2*jj)+1) : 2*jj];
    assign px_start_addr[jj]   = start_addr[((AWIDTH*jj)+(AWIDTH-1)) : AWIDTH*jj];
    assign px_end_addr[jj]     = end_addr[((AWIDTH*jj)+(AWIDTH-1)) : AWIDTH*jj];
    assign px_wrburst_size[jj] = wrburst_size[((9*jj)+8) : 9*jj];
    assign px_rdburst_size[jj] = rdburst_size[((9*jj)+8) : 9*jj];
`endif    
    assign px_str_wr_tdata[jj] = axi_str_wr_tdata[((AXIS_TDATA_WIDTH*jj)+(AXIS_TDATA_WIDTH-1)) : (AXIS_TDATA_WIDTH*jj)];
    assign px_axi_str_wr_tuser[jj] = axi_str_wr_tuser[((16*jj)+(16-1)) : (16*jj)];
    assign px_str_wr_tkeep[jj] = axi_str_wr_tkeep[(((AXIS_TDATA_WIDTH/8)*jj)+((AXIS_TDATA_WIDTH/8)-1)) : ((AXIS_TDATA_WIDTH/8)*jj)];
    end
  end
endgenerate

  //- Packet FIFO Instances based on NUM_PORTS parameter 

generate
  begin: multiple_pfifo
  for (i=0; i<NUM_PORTS; i=i+1)
  begin
  packetized_vfifo_controller #(
    .AXIS_TDATA_WIDTH           (AXIS_TDATA_WIDTH),
    .AXI_VFIFO_DATA_WIDTH       (AXI_VFIFO_DATA_WIDTH),
    .AWIDTH                     (AWIDTH),
    .DWIDTH                     (DWIDTH),
    .ISSUANCE_LEVEL             (ISSUANCE_LEVEL),
    .ID_WIDTH                   (ID_WIDTH),
    .CNTWIDTH                   (CNTWIDTH)
  ) pvfifo_ctlr_inst (
    .axi_str_wr_tdata           (px_str_wr_tdata[i]),
    .axi_str_wr_tkeep           (px_str_wr_tkeep[i]),
    .axi_str_wr_tvalid          (axi_str_wr_tvalid[i]),
    .axi_str_wr_tuser           (px_axi_str_wr_tuser[i]),
    .axi_str_wr_tlast           (axi_str_wr_tlast[i]),
    .axi_str_wr_tready          (axi_str_wr_tready[i]),
    .axis_wr_aclk               (axi_str_wr_aclk[i]),
    .axi_str_rd_tdata           (px_str_rd_tdata[i]),
    .axi_str_rd_tkeep           (px_str_rd_tkeep[i]),
    .axi_str_rd_tvalid          (axi_str_rd_tvalid[i]),
    .axi_str_rd_tlast           (axi_str_rd_tlast[i]),
    .axi_str_rd_tready          (axi_str_rd_tready[i]),
    .axis_rd_aclk               (axi_str_rd_aclk[i]),
    .rd_data_cnt                (px_vf_rd_data_cnt[i]),
    .wr_data_cnt                (px_vf_wr_data_cnt[i]),
    .ddr3_fifo_empty            (ddr3_fifo_empty[i]),
    .axi_str_rd_tuser           (px_rd_tuser[i]), 
`ifdef USE_DDR3_FIFO    
    .axi_awid                   (px_awid[i]),
    .axi_awaddr                 (px_awaddr[i]),
    .axi_awlen                  (px_awlen[i]),
    .axi_awsize                 (px_awsize[i]),
    .axi_awburst                (px_awburst[i]),
    .axi_awlock                 (px_awlock[i]),
    .axi_awcache                (px_awcache[i]),
    .axi_awprot                 (px_awprot[i]),
    .axi_awqos                  (px_awqos[i]),
    .axi_awvalid                (axi_awvalid[i]),
    .axi_awready                (axi_awready[i]),
    .axi_arid                   (px_arid[i]),
    .axi_araddr                 (px_araddr[i]),
    .axi_arlen                  (px_arlen[i]),
    .axi_arsize                 (px_arsize[i]),
    .axi_arburst                (px_arburst[i]),
    .axi_arlock                 (px_arlock[i]),
    .axi_arcache                (px_arcache[i]),
    .axi_arprot                 (px_arprot[i]),
    .axi_arqos                  (px_arqos[i]),
    .axi_arvalid                (axi_arvalid[i]),
    .axi_arready                (axi_arready[i]),
    .axi_bid                    (px_bid[i]),
    .axi_bresp                  (px_bresp[i]),
    .axi_bvalid                 (axi_bvalid[i]),
    .axi_bready                 (axi_bready[i]),
    .axi_wlast                  (axi_wlast[i]),
    .axi_wdata                  (px_wdata[i]),
    .axi_wvalid                 (axi_wvalid[i]),
    .axi_wready                 (axi_wready[i]),
    .axi_wstrb                  (px_wstrb[i]),
    .axi_rlast                  (axi_rlast[i]),
    .axi_rdata                  (px_rdata[i]),
    .axi_rvalid                 (axi_rvalid[i]),
    .axi_rready                 (axi_rready[i]),
    .axi_rstrb                  (px_rstrb[i]),
    .axi_rresp                  (px_rresp[i]),
    .start_address              (px_start_addr[i]),
    .end_address                (px_end_addr[i]),
    .wr_burst_size              (px_wrburst_size[i]),
    .rd_burst_size              (px_rdburst_size[i]),
    .mcb_clk                    (mcb_clk),
    .mcb_rst                    (!calib_done),
`endif
    .wr_reset_n                 (wr_reset_n[i]),
    .rd_reset_n                 (rd_reset_n[i])
);    
    end
  end
endgenerate  

`ifdef USE_DDR3_FIFO
/*
 * Multiport Memory Controller Instance 
 */

`ifdef VERIF
  multiport_mc_verif #(
`else
  multiport_mc #(
`endif
    .AXIS_TDATA_WIDTH           (AXIS_TDATA_WIDTH),
    .AXI_MIG_DATA_WIDTH         (AXI_MIG_DATA_WIDTH),
    .AWIDTH                     (AWIDTH),
    .ID_WIDTH                   (ID_WIDTH)
  ) mp_mc_inst (
   // interface to AXI MM write address port
     .calib_done                       (calib_done            ),   
     .sys_clk_p                        (sys_clk_p             ), 
     .sys_clk_n                        (sys_clk_n             ), 
     .ddr_addr                         (ddr_addr              ),
     .ddr_ba                           (ddr_ba                ),
     .ddr_cas_n                        (ddr_cas_n             ),
     .ddr_ck_p                         (ddr_ck_p              ),
     .ddr_ck_n                         (ddr_ck_n              ),
     .ddr_cke                          (ddr_cke               ),
     .ddr_cs_n                         (ddr_cs_n              ),
     .ddr_dm                           (ddr_dm                ),
     .ddr_dq                           (ddr_dq                ),
     .ddr_dqs_p                        (ddr_dqs_p             ),
     .ddr_dqs_n                        (ddr_dqs_n             ),
     .ddr_odt                          (ddr_odt               ),
     .ddr_ras_n                        (ddr_ras_n             ),
     .ddr_reset_n                      (ddr_reset_n           ),
     .ddr_we_n                         (ddr_we_n              ),
     //.sda                              (sda                   ),Bokka
     //.scl                              (scl                   ),Bokka
//     .px_axi_awid                         (px_axi_awid            ),
     .px_axi_awaddr                       (axi_awaddr          ),
     .px_axi_awlen                        (axi_awlen           ),
     .px_axi_awsize                       (axi_awsize          ),
     .px_axi_awburst                      (axi_awburst         ),
     .px_axi_awlock                       (axi_awlock          ),
     .px_axi_awcache                      (axi_awcache         ),
     .px_axi_awprot                       (axi_awprot          ),
     .px_axi_awqos                        (axi_awqos           ),
     .px_axi_awvalid                      (axi_awvalid         ),
     .px_axi_awready                      (axi_awready         ),
   // interface to AXI MM read address port
     .px_axi_arid                         (axi_arid            ),
     .px_axi_araddr                       (axi_araddr          ),
     .px_axi_arlen                        (axi_arlen           ),
     .px_axi_arsize                       (axi_arsize          ),
     .px_axi_arburst                      (axi_arburst         ),
     .px_axi_arlock                       (axi_arlock          ),
     .px_axi_arcache                      (axi_arcache         ),
     .px_axi_arprot                       (axi_arprot          ),
     .px_axi_arqos                        (axi_arqos           ),
     .px_axi_arvalid                      (axi_arvalid         ),
     .px_axi_arready                      (axi_arready         ),

   // interface to AXI MM write address response port
     .px_axi_bid                          (axi_bid             ),
     .px_axi_bresp                        (axi_bresp           ),
     .px_axi_bvalid                       (axi_bvalid          ),
     .px_axi_bready                       (axi_bready          ),


   // AXI MM Write Data Interface
     .px_axi_wlast                        (axi_wlast           ),               
     .px_axi_wdata                        (axi_wdata           ),
     .px_axi_wvalid                       (axi_wvalid          ),
     .px_axi_wready                       (axi_wready          ),
     .px_axi_wstrb                        (axi_wstrb           ),

   // AXI MM Read Data Interface
     .px_axi_rid                          (axi_rid             ),
     .px_axi_rlast                        (axi_rlast           ),               
     .px_axi_rdata                        (axi_rdata           ),
     .px_axi_rvalid                       (axi_rvalid          ),
     .px_axi_rready                       (axi_rready          ),
//     .px_axi_rstrb     ({(NUM_PORTS*AXI_VFIFO_DATA_WIDTH/8){1'b1}}),
     .px_axi_rresp                        (axi_rresp           ),
 
     .mcb_clk                             (mcb_clk             ),
     .mcb_rst                             (mcb_rst             ),
    
     .axi_ic_mig_shim_rst_n               (axi_ic_mig_shim_rst_n_sync),
     .user_reset                          (user_reset          )
    );  
    
     synchronizer_simple #(.DATA_WIDTH (1)) sync_to_user_clk_1
     (
       .data_in          (axi_ic_mig_shim_rst_n),
       .new_clk          (mcb_clk),
       .data_out         (axi_ic_mig_shim_rst_n_sync)
     );

`endif



endmodule

