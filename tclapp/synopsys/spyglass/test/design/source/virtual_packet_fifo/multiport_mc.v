/*******************************************************************************
** � Copyright 2011 - 2012 Xilinx, Inc. All rights reserved.
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

module multiport_mc #(
  parameter AXIS_TDATA_WIDTH          = 128,
  parameter AXI_MIG_DATA_WIDTH        = 512,
  parameter AWIDTH                    = 32,
  parameter NUM_PORTS                 = 4,
  parameter ID_WIDTH                  = 2,
  parameter AXI_VFIFO_DATA_WIDTH      = AXIS_TDATA_WIDTH
) (  
    // DDR3 ports
    output                                              calib_done,
    input                                               sys_clk_p,
    input                                               sys_clk_n, 
    output [13:0]                                       ddr_addr,             
    output [2:0]                                        ddr_ba,               
    output                                              ddr_cas_n,            
    output                                              ddr_ck_p,               
    output                                              ddr_ck_n,             
    output                                              ddr_cke,              
    output                                              ddr_cs_n,             
    output [7:0]                                        ddr_dm,               
    inout  [63:0]                                       ddr_dq,               
    inout  [7:0]                                        ddr_dqs_p,              
    inout  [7:0]                                        ddr_dqs_n,            
    output                                              ddr_odt,              
    output                                              ddr_ras_n,            
    output                                              ddr_reset_n,          
    output                                              ddr_we_n,             
    inout                                               sda,
    output                                              scl,

    input [(AWIDTH * NUM_PORTS)-1:0]                    px_axi_awaddr,
    input [(8 * NUM_PORTS)-1:0]                         px_axi_awlen,
    input [(3 * NUM_PORTS)-1:0]                         px_axi_awsize,
    input [(2 * NUM_PORTS)-1:0]                         px_axi_awburst,
    input [(2 * NUM_PORTS)-1:0]                         px_axi_awlock,
    input [(4 * NUM_PORTS)-1:0]                         px_axi_awcache,
    input [(3 * NUM_PORTS)-1:0]                         px_axi_awprot,
    input [(4 * NUM_PORTS)-1:0]                         px_axi_awqos,
    input [NUM_PORTS-1:0]                               px_axi_awvalid,
    output [NUM_PORTS-1:0]                              px_axi_awready,
    input [(AXI_VFIFO_DATA_WIDTH * NUM_PORTS)-1:0]      px_axi_wdata,
    input [((AXI_VFIFO_DATA_WIDTH/8) * NUM_PORTS)-1:0]  px_axi_wstrb,
    input [NUM_PORTS-1:0]                               px_axi_wlast,
    input [NUM_PORTS-1:0]                               px_axi_wvalid,
    output [NUM_PORTS-1:0]                              px_axi_wready,
    output [(4 * NUM_PORTS)-1:0]                        px_axi_bid,
    output [(2 * NUM_PORTS)-1:0]                        px_axi_bresp,
    output [NUM_PORTS-1:0]                              px_axi_bvalid,
    input [NUM_PORTS-1:0]                               px_axi_bready,
    input [(4 * NUM_PORTS)-1:0]                         px_axi_arid,
    input [(AWIDTH * NUM_PORTS)-1:0]                    px_axi_araddr,
    input [(8 * NUM_PORTS)-1:0]                         px_axi_arlen,
    input [(3 * NUM_PORTS)-1:0]                         px_axi_arsize,
    input [(2 * NUM_PORTS)-1:0]                         px_axi_arburst,
    input [(2 * NUM_PORTS)-1:0]                         px_axi_arlock,
    input [(4 * NUM_PORTS)-1:0]                         px_axi_arcache,
    input [(3 * NUM_PORTS)-1:0]                         px_axi_arprot,
    input [(4 * NUM_PORTS)-1:0]                         px_axi_arqos,
    input [NUM_PORTS-1:0]                               px_axi_arvalid,
    output [NUM_PORTS-1:0]                              px_axi_arready,

    output [(4 * NUM_PORTS)-1:0]                        px_axi_rid,
    output [(AXI_VFIFO_DATA_WIDTH * NUM_PORTS)-1:0]     px_axi_rdata,
    output [(2 * NUM_PORTS)-1:0]                        px_axi_rresp,
    output [NUM_PORTS-1:0]                              px_axi_rlast,
    output [NUM_PORTS-1:0]                              px_axi_rvalid,
    input [NUM_PORTS-1:0]                               px_axi_rready,

    output                                              mcb_clk,
    output                                              mcb_rst,
    input                                               axi_ic_mig_shim_rst_n,
    input                                               user_reset
  );


wire [31:0]                             s_axi_awaddr;
wire [7:0]                              s_axi_awlen;
wire [2:0]                              s_axi_awsize;
wire [1:0]                              s_axi_awburst;
wire [0:0]                              s_axi_awlock;
wire [3:0]                              s_axi_awcache;
wire [2:0]                              s_axi_awprot;
wire [3:0]                              s_axi_awqos;
wire                                    s_axi_awvalid;
wire                                    s_axi_awready;
wire [AXI_MIG_DATA_WIDTH-1:0]           s_axi_wdata;
wire [AXI_MIG_DATA_WIDTH/8-1:0]         s_axi_wstrb;
wire                                    s_axi_wlast;
wire                                    s_axi_wvalid;
wire                                    s_axi_wready;
wire [1:0]                              s_axi_bresp;
wire                                    s_axi_bvalid;
wire                                    s_axi_bready;
wire [31:0]                             s_axi_araddr;
wire [7:0]                              s_axi_arlen;
wire [2:0]                              s_axi_arsize;
wire [1:0]                              s_axi_arburst;
wire [0:0]                              s_axi_arlock;
wire [3:0]                              s_axi_arcache;
wire [2:0]                              s_axi_arprot;
wire [3:0]                              s_axi_arqos;
wire                                    s_axi_arvalid;
wire                                    s_axi_arready;
wire [AXI_MIG_DATA_WIDTH-1:0]           s_axi_rdata;
wire [1:0]                              s_axi_rresp;
wire                                    s_axi_rlast;
wire                                    s_axi_rvalid;
wire                                    s_axi_rready;
`ifdef USE_XPS_IC
wire [ID_WIDTH-1:0]                     s_axi_rid;
wire [ID_WIDTH-1:0]                     s_axi_bid;
wire [ID_WIDTH-1:0]                     s_axi_awid;
wire [ID_WIDTH-1:0]                     s_axi_arid;
`else
wire [3:0]                              s_axi_rid;
wire [3:0]                              s_axi_bid;
wire [3:0]                              s_axi_awid;
wire [3:0]                              s_axi_arid;
`endif

wire                                    axi_rst_n;

assign axi_rst_n = calib_done & axi_ic_mig_shim_rst_n;

axi_interconnect_4m_1s axi_ic_inst 
(

        .INTERCONNECT_ACLK        ( mcb_clk                                       ),
        .INTERCONNECT_ARESETN     ( axi_rst_n                                     ),

        .S00_AXI_ARESET_OUT_N     (                                               ),
        .S00_AXI_ACLK             ( mcb_clk                                       ),
        .S00_AXI_AWID             ( 1'b0                                          ),
        .S00_AXI_AWADDR           ( px_axi_awaddr[(AWIDTH*(0+1))-1:(AWIDTH*0)]    ),
        .S00_AXI_AWLEN            ( px_axi_awlen[(8*(0+1))-1:(8*0)]               ),
        .S00_AXI_AWSIZE           ( px_axi_awsize[(3*(0+1))-1:(3*0)]              ),
        .S00_AXI_AWBURST          ( px_axi_awburst[(2*(0+1))-1:(2*0)]             ),
        .S00_AXI_AWLOCK           ( 1'b0                                          ), 
        .S00_AXI_AWCACHE          ( px_axi_awcache[(4*(0+1))-1:(4*0)]             ),
        .S00_AXI_AWPROT           ( px_axi_awprot[(3*(0+1))-1:(3*0)]              ),
        .S00_AXI_AWQOS            ( px_axi_awqos[(4*(0+1))-1:(4*0)]               ),
        .S00_AXI_AWVALID          ( px_axi_awvalid[0]                             ),
        .S00_AXI_AWREADY          ( px_axi_awready[0]                             ),
        .S00_AXI_WDATA            ( px_axi_wdata[(AXI_VFIFO_DATA_WIDTH*(0+1))-1:(AXI_VFIFO_DATA_WIDTH*0)]     ),
        .S00_AXI_WSTRB            ( px_axi_wstrb[(AXI_VFIFO_DATA_WIDTH/8*(0+1))-1:(AXI_VFIFO_DATA_WIDTH/8*0)] ),
        .S00_AXI_WLAST            ( px_axi_wlast[0]                               ),
        .S00_AXI_WVALID           ( px_axi_wvalid[0]                              ),
        .S00_AXI_WREADY           ( px_axi_wready[0]                              ),
        .S00_AXI_BID              ( px_axi_bid[(ID_WIDTH*(0+1))-1:(ID_WIDTH*0)]   ),
        .S00_AXI_BRESP            ( px_axi_bresp[(2*(0+1))-1:(2*0)]               ),
        .S00_AXI_BVALID           ( px_axi_bvalid[0]                              ),
        .S00_AXI_BREADY           ( px_axi_bready[0]                              ),
        .S00_AXI_ARID             ( 1'b0                                          ),
        .S00_AXI_ARADDR           ( px_axi_araddr[(AWIDTH*(0+1))-1:(AWIDTH*0)]    ),
        .S00_AXI_ARLEN            ( px_axi_arlen[(8*(0+1))-1:(8*0)]               ),
        .S00_AXI_ARSIZE           ( px_axi_arsize[(3*(0+1))-1:(3*0)]              ),
        .S00_AXI_ARBURST          ( px_axi_arburst[(2*(0+1))-1:(2*0)]             ),
        .S00_AXI_ARLOCK           ( 1'b0                                          ),  
        .S00_AXI_ARCACHE          ( px_axi_arcache[(4*(0+1))-1:(4*0)]             ),
        .S00_AXI_ARPROT           ( px_axi_arprot[(3*(0+1))-1:(3*0)]              ),
        .S00_AXI_ARQOS            ( px_axi_arqos[(4*(0+1))-1:(4*0)]               ),
        .S00_AXI_ARVALID          ( px_axi_arvalid[0]                             ),
        .S00_AXI_ARREADY          ( px_axi_arready[0]                             ),
        .S00_AXI_RID              ( px_axi_rid[(ID_WIDTH*(0+1))-1:(ID_WIDTH*0)]   ),
        .S00_AXI_RDATA            ( px_axi_rdata[(AXI_VFIFO_DATA_WIDTH*(0+1))-1:(AXI_VFIFO_DATA_WIDTH*0)]     ),
        .S00_AXI_RRESP            ( px_axi_rresp[(2*(0+1))-1:(2*0)]               ),
        .S00_AXI_RLAST            ( px_axi_rlast[0]                               ),
        .S00_AXI_RVALID           ( px_axi_rvalid[0]                              ),
        .S00_AXI_RREADY           ( px_axi_rready[0]                              ),

        .S01_AXI_ARESET_OUT_N     (                                               ),
        .S01_AXI_ACLK             ( mcb_clk                                       ),
        .S01_AXI_AWID             ( 1'b1                                          ),
        .S01_AXI_AWADDR           ( px_axi_awaddr[(AWIDTH*(1+1))-1:(AWIDTH*1)]    ),
        .S01_AXI_AWLEN            ( px_axi_awlen[(8*(1+1))-1:(8*1)]               ),
        .S01_AXI_AWSIZE           ( px_axi_awsize[(3*(1+1))-1:(3*1)]              ),
        .S01_AXI_AWBURST          ( px_axi_awburst[(2*(1+1))-1:(2*1)]             ),
        .S01_AXI_AWLOCK           ( 1'b0                                          ), 
        .S01_AXI_AWCACHE          ( px_axi_awcache[(4*(1+1))-1:(4*1)]             ),
        .S01_AXI_AWPROT           ( px_axi_awprot[(3*(1+1))-1:(3*1)]              ),
        .S01_AXI_AWQOS            ( px_axi_awqos[(4*(1+1))-1:(4*1)]               ),
        .S01_AXI_AWVALID          ( px_axi_awvalid[1]                             ),
        .S01_AXI_AWREADY          ( px_axi_awready[1]                             ),
        .S01_AXI_WDATA            ( px_axi_wdata[(AXI_VFIFO_DATA_WIDTH*(1+1))-1:(AXI_VFIFO_DATA_WIDTH*1)]     ),
        .S01_AXI_WSTRB            ( px_axi_wstrb[(AXI_VFIFO_DATA_WIDTH/8*(1+1))-1:(AXI_VFIFO_DATA_WIDTH/8*1)] ),
        .S01_AXI_WLAST            ( px_axi_wlast[1]                               ),
        .S01_AXI_WVALID           ( px_axi_wvalid[1]                              ),
        .S01_AXI_WREADY           ( px_axi_wready[1]                              ),
        .S01_AXI_BID              ( px_axi_bid[(ID_WIDTH*(1+1))-1:(ID_WIDTH*1)]   ),
        .S01_AXI_BRESP            ( px_axi_bresp[(2*(1+1))-1:(2*1)]               ),
        .S01_AXI_BVALID           ( px_axi_bvalid[1]                              ),
        .S01_AXI_BREADY           ( px_axi_bready[1]                              ),
        .S01_AXI_ARID             (1'b1                                           ),
        .S01_AXI_ARADDR           ( px_axi_araddr[(AWIDTH*(1+1))-1:(AWIDTH*1)]    ),
        .S01_AXI_ARLEN            ( px_axi_arlen[(8*(1+1))-1:(8*1)]               ),
        .S01_AXI_ARSIZE           ( px_axi_arsize[(3*(1+1))-1:(3*1)]              ),
        .S01_AXI_ARBURST          ( px_axi_arburst[(2*(1+1))-1:(2*1)]             ),
        .S01_AXI_ARLOCK           ( 1'b0                                          ), 
        .S01_AXI_ARCACHE          ( px_axi_arcache[(4*(1+1))-1:(4*1)]             ),
        .S01_AXI_ARPROT           ( px_axi_arprot[(3*(1+1))-1:(3*1)]              ),
        .S01_AXI_ARQOS            ( px_axi_arqos[(4*(1+1))-1:(4*1)]               ),
        .S01_AXI_ARVALID          ( px_axi_arvalid[1]                             ),
        .S01_AXI_ARREADY          ( px_axi_arready[1]                             ),
        .S01_AXI_RID              ( px_axi_rid[(ID_WIDTH*(1+1))-1:(ID_WIDTH*1)]   ),
        .S01_AXI_RDATA            ( px_axi_rdata[(AXI_VFIFO_DATA_WIDTH*(1+1))-1:(AXI_VFIFO_DATA_WIDTH*1)]     ),
        .S01_AXI_RRESP            ( px_axi_rresp[(2*(1+1))-1:(2*1)]               ),
        .S01_AXI_RLAST            ( px_axi_rlast[1]                               ),
        .S01_AXI_RVALID           ( px_axi_rvalid[1]                              ),
        .S01_AXI_RREADY           ( px_axi_rready[1]                              ),

        .S02_AXI_ARESET_OUT_N     (                                               ),
        .S02_AXI_ACLK             ( mcb_clk                                       ),
        .S02_AXI_AWID             ( 1'b1                                          ),
        .S02_AXI_AWADDR           ( px_axi_awaddr[(AWIDTH*(2+1))-1:(AWIDTH*2)]    ),
        .S02_AXI_AWLEN            ( px_axi_awlen[(8*(2+1))-1:(8*2)]               ),
        .S02_AXI_AWSIZE           ( px_axi_awsize[(3*(2+1))-1:(3*2)]              ),
        .S02_AXI_AWBURST          ( px_axi_awburst[(2*(2+1))-1:(2*2)]             ),
        .S02_AXI_AWLOCK           ( 1'b0                                          ),  
        .S02_AXI_AWCACHE          ( px_axi_awcache[(4*(2+1))-1:(4*2)]             ),
        .S02_AXI_AWPROT           ( px_axi_awprot[(3*(2+1))-1:(3*2)]              ),
        .S02_AXI_AWQOS            ( px_axi_awqos[(4*(2+1))-1:(4*2)]               ),
        .S02_AXI_AWVALID          ( px_axi_awvalid[2]                             ),
        .S02_AXI_AWREADY          ( px_axi_awready[2]                             ),
        .S02_AXI_WDATA            ( px_axi_wdata[(AXI_VFIFO_DATA_WIDTH*(2+1))-1:(AXI_VFIFO_DATA_WIDTH*2)]     ),
        .S02_AXI_WSTRB            ( px_axi_wstrb[(AXI_VFIFO_DATA_WIDTH/8*(2+1))-1:(AXI_VFIFO_DATA_WIDTH/8*2)] ),
        .S02_AXI_WLAST            ( px_axi_wlast[2]                               ),
        .S02_AXI_WVALID           ( px_axi_wvalid[2]                              ),
        .S02_AXI_WREADY           ( px_axi_wready[2]                              ),
        .S02_AXI_BID              ( px_axi_bid[(ID_WIDTH*(2+1))-1:(ID_WIDTH*2)]   ),
        .S02_AXI_BRESP            ( px_axi_bresp[(2*(2+1))-1:(2*2)]               ),
        .S02_AXI_BVALID           ( px_axi_bvalid[2]                              ),
        .S02_AXI_BREADY           ( px_axi_bready[2]                              ),
        .S02_AXI_ARID             ( 1'b0                                          ),
        .S02_AXI_ARADDR           ( px_axi_araddr[(AWIDTH*(2+1))-1:(AWIDTH*2)]    ),
        .S02_AXI_ARLEN            ( px_axi_arlen[(8*(2+1))-1:(8*2)]               ),
        .S02_AXI_ARSIZE           ( px_axi_arsize[(3*(2+1))-1:(3*2)]              ),
        .S02_AXI_ARBURST          ( px_axi_arburst[(2*(2+1))-1:(2*2)]             ),
        .S02_AXI_ARLOCK           ( 1'b0                                          ),  
        .S02_AXI_ARCACHE          ( px_axi_arcache[(4*(2+1))-1:(4*2)]             ),
        .S02_AXI_ARPROT           ( px_axi_arprot[(3*(2+1))-1:(3*2)]              ),
        .S02_AXI_ARQOS            ( px_axi_arqos[(4*(2+1))-1:(4*2)]               ),
        .S02_AXI_ARVALID          ( px_axi_arvalid[2]                             ),
        .S02_AXI_ARREADY          ( px_axi_arready[2]                             ),
        .S02_AXI_RID              ( px_axi_rid[(ID_WIDTH*(2+1))-1:(ID_WIDTH*2)]   ),
        .S02_AXI_RDATA            ( px_axi_rdata[(AXI_VFIFO_DATA_WIDTH*(2+1))-1:(AXI_VFIFO_DATA_WIDTH*2)]     ),
        .S02_AXI_RRESP            ( px_axi_rresp[(2*(2+1))-1:(2*2)]               ),
        .S02_AXI_RLAST            ( px_axi_rlast[2]                               ),
        .S02_AXI_RVALID           ( px_axi_rvalid[2]                              ),
        .S02_AXI_RREADY           ( px_axi_rready[2]                              ),

        .S03_AXI_ARESET_OUT_N     (                                               ),
        .S03_AXI_ACLK             ( mcb_clk                                       ),
        .S03_AXI_AWID             ( 1'b1                                          ),
        .S03_AXI_AWADDR           ( px_axi_awaddr[(AWIDTH*(3+1))-1:(AWIDTH*3)]    ),
        .S03_AXI_AWLEN            ( px_axi_awlen[(8*(3+1))-1:(8*3)]               ),
        .S03_AXI_AWSIZE           ( px_axi_awsize[(3*(3+1))-1:(3*3)]              ),
        .S03_AXI_AWBURST          ( px_axi_awburst[(2*(3+1))-1:(2*3)]             ),
        .S03_AXI_AWLOCK           ( 1'b0                                          ),  
        .S03_AXI_AWCACHE          ( px_axi_awcache[(4*(3+1))-1:(4*3)]             ),
        .S03_AXI_AWPROT           ( px_axi_awprot[(3*(3+1))-1:(3*3)]              ),
        .S03_AXI_AWQOS            ( px_axi_awqos[(4*(3+1))-1:(4*3)]               ),
        .S03_AXI_AWVALID          ( px_axi_awvalid[3]                             ),
        .S03_AXI_AWREADY          ( px_axi_awready[3]                             ),
        .S03_AXI_WDATA            ( px_axi_wdata[(AXI_VFIFO_DATA_WIDTH*(3+1))-1:(AXI_VFIFO_DATA_WIDTH*3)]     ),
        .S03_AXI_WSTRB            ( px_axi_wstrb[(AXI_VFIFO_DATA_WIDTH/8*(3+1))-1:(AXI_VFIFO_DATA_WIDTH/8*3)] ),
        .S03_AXI_WLAST            ( px_axi_wlast[3]                               ),
        .S03_AXI_WVALID           ( px_axi_wvalid[3]                              ),
        .S03_AXI_WREADY           ( px_axi_wready[3]                              ),
        .S03_AXI_BID              ( px_axi_bid[(ID_WIDTH*(3+1))-1:(ID_WIDTH*3)]   ),
        .S03_AXI_BRESP            ( px_axi_bresp[(2*(3+1))-1:(2*3)]               ),
        .S03_AXI_BVALID           ( px_axi_bvalid[3]                              ),
        .S03_AXI_BREADY           ( px_axi_bready[3]                              ),
        .S03_AXI_ARID             ( 1'b1                                          ),
        .S03_AXI_ARADDR           ( px_axi_araddr[(AWIDTH*(3+1))-1:(AWIDTH*3)]    ),
        .S03_AXI_ARLEN            ( px_axi_arlen[(8*(3+1))-1:(8*3)]               ),
        .S03_AXI_ARSIZE           ( px_axi_arsize[(3*(3+1))-1:(3*3)]              ),
        .S03_AXI_ARBURST          ( px_axi_arburst[(2*(3+1))-1:(2*3)]             ),
        .S03_AXI_ARLOCK           ( 1'b0                                          ),  
        .S03_AXI_ARCACHE          ( px_axi_arcache[(4*(3+1))-1:(4*3)]             ),
        .S03_AXI_ARPROT           ( px_axi_arprot[(3*(3+1))-1:(3*3)]              ),
        .S03_AXI_ARQOS            ( px_axi_arqos[(4*(3+1))-1:(4*3)]               ),
        .S03_AXI_ARVALID          ( px_axi_arvalid[3]                             ),
        .S03_AXI_ARREADY          ( px_axi_arready[3]                             ),
        .S03_AXI_RID              ( px_axi_rid[(ID_WIDTH*(3+1))-1:(ID_WIDTH*3)]   ),
        .S03_AXI_RDATA            ( px_axi_rdata[(AXI_VFIFO_DATA_WIDTH*(3+1))-1:(AXI_VFIFO_DATA_WIDTH*3)]     ),
        .S03_AXI_RRESP            ( px_axi_rresp[(2*(3+1))-1:(2*3)]               ),
        .S03_AXI_RLAST            ( px_axi_rlast[3]                               ),
        .S03_AXI_RVALID           ( px_axi_rvalid[3]                              ),
        .S03_AXI_RREADY           ( px_axi_rready[3]                              ),

        .M00_AXI_ARESET_OUT_N     (                                               ),
        .M00_AXI_ACLK             ( mcb_clk                                       ),
        .M00_AXI_AWID             ( s_axi_awid                                    ),
        .M00_AXI_AWADDR           ( s_axi_awaddr                                  ),
        .M00_AXI_AWLEN            ( s_axi_awlen                                   ),
        .M00_AXI_AWSIZE           ( s_axi_awsize                                  ),
        .M00_AXI_AWBURST          ( s_axi_awburst                                 ),
        .M00_AXI_AWLOCK           ( s_axi_awlock                                  ),
        .M00_AXI_AWCACHE          ( s_axi_awcache                                 ),
        .M00_AXI_AWPROT           ( s_axi_awprot                                  ),
        .M00_AXI_AWQOS            ( s_axi_awqos                                   ),
        .M00_AXI_AWVALID          ( s_axi_awvalid                                 ),
        .M00_AXI_AWREADY          ( s_axi_awready                                 ),
        .M00_AXI_WDATA            ( s_axi_wdata                                   ),
        .M00_AXI_WSTRB            ( s_axi_wstrb                                   ),
        .M00_AXI_WLAST            ( s_axi_wlast                                   ),
        .M00_AXI_WVALID           ( s_axi_wvalid                                  ),
        .M00_AXI_WREADY           ( s_axi_wready                                  ),
        .M00_AXI_BID              ( s_axi_bid                                     ),
        .M00_AXI_BRESP            ( s_axi_bresp                                   ),
        .M00_AXI_BVALID           ( s_axi_bvalid                                  ),
        .M00_AXI_BREADY           ( s_axi_bready                                  ),
        .M00_AXI_ARID             ( s_axi_arid                                    ),
        .M00_AXI_ARADDR           ( s_axi_araddr                                  ),
        .M00_AXI_ARLEN            ( s_axi_arlen                                   ),
        .M00_AXI_ARSIZE           ( s_axi_arsize                                  ),
        .M00_AXI_ARBURST          ( s_axi_arburst                                 ),
        .M00_AXI_ARLOCK           ( s_axi_arlock                                  ),
        .M00_AXI_ARCACHE          ( s_axi_arcache                                 ),
        .M00_AXI_ARPROT           ( s_axi_arprot                                  ),
        .M00_AXI_ARQOS            ( s_axi_arqos                                   ),
        .M00_AXI_ARVALID          ( s_axi_arvalid                                 ),
        .M00_AXI_ARREADY          ( s_axi_arready                                 ),
        .M00_AXI_RID              ( s_axi_rid                                     ),
        .M00_AXI_RDATA            ( s_axi_rdata                                   ),
        .M00_AXI_RRESP            ( s_axi_rresp                                   ),
        .M00_AXI_RLAST            ( s_axi_rlast                                   ),
        .M00_AXI_RVALID           ( s_axi_rvalid                                  ),
        .M00_AXI_RREADY           ( s_axi_rready                                  )
);


  mig_7x 
  //#(
 // `ifdef SIMULATION
 // .SIM_BYPASS_INIT_CAL                   ( "FAST"                ), 
 // .SIMULATION                            ( "TRUE"                ),
//  `endif                                   
  //.C_S_AXI_DATA_WIDTH                    ( AXI_MIG_DATA_WIDTH    ),
 // .C_S_AXI_ID_WIDTH                      ( 4                     ), 
                                           
                                           
 // .DEBUG_PORT                            ( "OFF"                 ), 
 // .RST_ACT_LOW                           ( 0                     )   )
 mig_inst (                               
  .ddr3_addr                             ( ddr_addr              ),
  .ddr3_ba                               ( ddr_ba                ),
  .ddr3_cas_n                            ( ddr_cas_n             ),
  .ddr3_ck_p                             ( ddr_ck_p              ),
  .ddr3_ck_n                             ( ddr_ck_n              ),
  .ddr3_cke                              ( ddr_cke               ),
  .ddr3_cs_n                             ( ddr_cs_n              ),
  .ddr3_dm                               ( ddr_dm                ),
  .ddr3_odt                              ( ddr_odt               ),
  .ddr3_ras_n                            ( ddr_ras_n             ),
  .ddr3_reset_n                          ( ddr_reset_n           ),
  .ddr3_we_n                             ( ddr_we_n              ),
  .ddr3_dq                               ( ddr_dq                ),
  .ddr3_dqs_p                            ( ddr_dqs_p             ),
  .ddr3_dqs_n                            ( ddr_dqs_n             ),
  .ui_clk                                ( mcb_clk               ),
  .ui_clk_sync_rst                       ( mcb_rst               ),
  .sys_clk_p                             ( sys_clk_p             ),    
  .sys_clk_n                             ( sys_clk_n             ),    
  .sys_rst                               ( user_reset),
  .app_sr_req                            ( 1'b0                  ),
  .app_sr_active                         (                       ),  
 .app_ref_req                           ( 1'b0                  ),
  .app_ref_ack                           (                       ),
  .app_zq_req                            ( 1'b0                  ),
  .app_zq_ack                            (                       ),
  .init_calib_complete                   ( calib_done            ),   
  .aresetn                               ( axi_rst_n             ),
  .s_axi_awid                            ( s_axi_awid            ),
  .s_axi_awaddr                          ( s_axi_awaddr          ),
  .s_axi_awlen                           ( s_axi_awlen           ),
  .s_axi_awsize                          ( s_axi_awsize          ),
  .s_axi_awburst                         ( s_axi_awburst         ),
  .s_axi_awlock                          ( s_axi_awlock          ),
  .s_axi_awcache                         ( s_axi_awcache         ),
  .s_axi_awprot                          ( s_axi_awprot          ),
  .s_axi_awqos                           ( s_axi_awqos           ),
  .s_axi_awvalid                         ( s_axi_awvalid         ),
  .s_axi_awready                         ( s_axi_awready         ),
  .s_axi_wdata                           ( s_axi_wdata           ),
  .s_axi_wstrb                           ( s_axi_wstrb           ),
  .s_axi_wlast                           ( s_axi_wlast           ),
  .s_axi_wvalid                          ( s_axi_wvalid          ),
  .s_axi_wready                          ( s_axi_wready          ),
  .s_axi_bid                             ( s_axi_bid             ),
  .s_axi_bresp                           ( s_axi_bresp           ),
  .s_axi_bvalid                          ( s_axi_bvalid          ),
  .s_axi_bready                          ( s_axi_bready          ),
  .s_axi_arid                            ( s_axi_arid            ),
  .s_axi_araddr                          ( s_axi_araddr          ),
  .s_axi_arlen                           ( s_axi_arlen           ),
  .s_axi_arsize                          ( s_axi_arsize          ),
  .s_axi_arburst                         ( s_axi_arburst         ),
  .s_axi_arlock                          ( s_axi_arlock          ),
  .s_axi_arcache                         ( s_axi_arcache         ),
  .s_axi_arprot                          ( s_axi_arprot          ),
  .s_axi_arqos                           ( s_axi_arqos           ),
  .s_axi_arvalid                         ( s_axi_arvalid         ),
  .s_axi_arready                         ( s_axi_arready         ),
  .s_axi_rid                             ( s_axi_rid             ),
  .s_axi_rdata                           ( s_axi_rdata           ),
  .s_axi_rresp                           ( s_axi_rresp           ),
  .s_axi_rlast                           ( s_axi_rlast           ),
  .s_axi_rvalid                          ( s_axi_rvalid          ),
  .s_axi_rready                          ( s_axi_rready          )
); 

`ifdef KC705
  MUXCY scl_inst
    (
     .O  (scl),
     .CI (scl_i),
     .DI (1'b0),
     .S  (1'b1)
     );

  MUXCY sda_inst
    (
     .O  (sda),
     .CI (sda_i),
     .DI (1'b0),
     .S  (1'b1)
     );
`endif

//generate
//  begin: gen_chipscope
//////  if (PORT_NUM == 0)
//////  begin
////
//     wire [767:0] ila_data;
//     wire [15:0] ila_trig;
//     wire [35:0] control;
//     
//     wire wr_addr_rdy = s_axi_awvalid & s_axi_awready;
//     wire wr_data_rdy = s_axi_wvalid & s_axi_wready;
//     wire rd_addr_rdy = s_axi_arvalid & s_axi_arready;
//     wire rd_data_rdy = s_axi_rvalid & s_axi_rready;
//     wire mig_active = wr_addr_rdy | wr_data_rdy | rd_addr_rdy | rd_data_rdy;
////
//     assign ila_data[1:0] = s_axi_awid[1:0]   ;  
//     assign ila_data[33:2] = s_axi_awaddr ;  
//     assign ila_data[41:34] = s_axi_awlen  ;  
//     assign ila_data[44:42] = s_axi_awsize ;  
//     assign ila_data[46:45] = s_axi_awburst;  
//     assign ila_data[47] = s_axi_awlock ;  
//     assign ila_data[51:48] = s_axi_awcache;  
//     assign ila_data[54:52] = s_axi_awprot ;  
//     assign ila_data[58:55] = s_axi_awqos  ;  
//     assign ila_data[59] = s_axi_awvalid;  
//     assign ila_data[60] = s_axi_awready;  
//     assign ila_data[124:61] = s_axi_wdata[63:0]  ;  // should be 256 bits, not 64
//     assign ila_data[132:125] = s_axi_wstrb[7:0]  ;  
//     assign ila_data[133] = s_axi_wlast  ;  
//     assign ila_data[134] = s_axi_wvalid ;  
//     assign ila_data[135] = s_axi_wready ;  
//     assign ila_data[137:136] = s_axi_bid[1:0]    ;  
//     assign ila_data[139:138] = s_axi_bresp  ;  
//     assign ila_data[140] = s_axi_bvalid ;  
//     assign ila_data[141] = s_axi_bready ;  
//     assign ila_data[143:142] = s_axi_arid[1:0]   ;  
//     assign ila_data[175:144] = s_axi_araddr ;  
//     assign ila_data[183:176] = s_axi_arlen  ;  
//     assign ila_data[186:184] = s_axi_arsize ;  
//     assign ila_data[188:187] = s_axi_arburst;  
//     assign ila_data[189] = s_axi_arlock ;  
//     assign ila_data[193:190] = s_axi_arcache;  
//     assign ila_data[196:194] = s_axi_arprot ;  
//     assign ila_data[200:197] = s_axi_arqos  ;  
//     assign ila_data[201] = s_axi_arvalid;  
//     assign ila_data[202] = s_axi_arready;  
//     assign ila_data[204:203] = s_axi_rid[1:0]    ;  
//     assign ila_data[268:205] = s_axi_rdata[63:0]  ;  // should be 256 bits, not 64
//     assign ila_data[270:269] = s_axi_rresp  ;  
//     assign ila_data[271] = s_axi_rlast  ;  
//     assign ila_data[272] = s_axi_rvalid ;  
//     assign ila_data[273] = s_axi_rready ;  
//     assign ila_data[274] = wr_addr_rdy;    
//     assign ila_data[275] = wr_data_rdy;   
//     assign ila_data[276] = rd_addr_rdy;    
//     assign ila_data[277] = rd_data_rdy;    
//     assign ila_data[278] = mig_active;    
//     assign ila_data[470:279] = s_axi_wdata[255:64];
//     assign ila_data[662:471] = s_axi_rdata[255:64];
//     assign ila_data[686:663] = s_axi_wstrb[31:8]; 
//     assign ila_data[688:687] = s_axi_awid[3:2];
//     assign ila_data[690:689] = s_axi_bid[3:2];
//     assign ila_data[692:691] = s_axi_arid[3:2];
//     assign ila_data[694:693] = s_axi_rid[3:2];
//     //assign ila_data[710:687] =     
//     
//     assign ila_data[695] = 'b0; //data_mismatch0;
//     // Unused
//     assign ila_data[767:696] = 'b0;
//     
//     // Triggers
//     assign ila_trig[0] = wr_addr_rdy;
//     assign ila_trig[1] = wr_data_rdy;
//     assign ila_trig[2] = rd_addr_rdy;
//     assign ila_trig[3] = rd_data_rdy;
//     assign ila_trig[4] = mig_active;
//     assign ila_trig[5] = 'b0; //data_mismatch0;
//     //assign ila_trig[6] = 
//     //assign ila_trig[7] = 
//     
//     // Unused Triggers
//     assign ila_trig[15:6] = 'b0;
//     
//     chipscope_ila_768 ila_0 (
//         .CONTROL(control), // INOUT BUS [35:0]
//         .CLK(mcb_clk), // IN
//         .DATA(ila_data), // IN BUS [767:0]
//         .TRIG0(ila_trig) // IN BUS [15:0]
//     );
//     
//     chipscope_icon icon_0 (
//        .CONTROL0(control) // INOUT BUS [35:0]
//     );
//
//     
//////   end
// end
//endgenerate

endmodule

