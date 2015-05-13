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

module packetized_vfifo_controller #(
  parameter integer AXIS_TDATA_WIDTH      = 64,
  parameter integer AXI_VFIFO_DATA_WIDTH  = 64,
  parameter integer ISSUANCE_LEVEL        = 2,
  parameter integer AWIDTH                = 32,
  parameter integer DWIDTH                = 64,
  parameter integer ID_WIDTH              = 4,
  parameter integer CNTWIDTH              = 10
) (
    //-Write AXI-ST interface
  input [AXIS_TDATA_WIDTH-1:0]      axi_str_wr_tdata,
  input [AXIS_TDATA_WIDTH/8 - 1:0]  axi_str_wr_tkeep,
  input                             axi_str_wr_tvalid,
  input [15:0]                      axi_str_wr_tuser, 
  input                             axi_str_wr_tlast,
  output                            axi_str_wr_tready,
  input                             axis_wr_aclk,
  
    //-Read AXI-ST interface
  output [AXIS_TDATA_WIDTH-1:0]     axi_str_rd_tdata,
  output [AXIS_TDATA_WIDTH/8 - 1:0] axi_str_rd_tkeep,
  output                            axi_str_rd_tvalid,
  output                            axi_str_rd_tlast,
  input                             axi_str_rd_tready,
  input                             axis_rd_aclk,
  output [CNTWIDTH-1:0]             rd_data_cnt, 
  output [CNTWIDTH-1:0]             wr_data_cnt, 
  output [15:0]                     axi_str_rd_tuser,
  output                            ddr3_fifo_empty,

`ifdef USE_DDR3_FIFO
  // Interface to AXI MM write address port
   output [ID_WIDTH-1:0]            axi_awid,
   output [AWIDTH-1:0]              axi_awaddr,
   output [7:0]                     axi_awlen,
   output [2:0]                     axi_awsize,
   output [1:0]                     axi_awburst,
   output [1:0]                     axi_awlock,
   output [3:0]                     axi_awcache,
   output [2:0]                     axi_awprot,
   output [3:0]                     axi_awqos,
   output                           axi_awvalid,
   input                            axi_awready,    

   // interface to AXI MM read address port
   output [ID_WIDTH-1:0]            axi_arid,
   output [AWIDTH-1:0]              axi_araddr,
   output [7:0]                     axi_arlen,
   output [2:0]                     axi_arsize,
   output [1:0]                     axi_arburst,
   output [1:0]                     axi_arlock,
   output [3:0]                     axi_arcache,
   output [2:0]                     axi_arprot,
   output [3:0]                     axi_arqos,
   output                           axi_arvalid,
   input                            axi_arready,

   // interface to AXI MM write address response port
   input  [ID_WIDTH-1:0]            axi_bid,
   input  [1:0]                     axi_bresp,
   input                            axi_bvalid,
   output                           axi_bready,

   // AXI MM Write Data Interface
   output                           axi_wlast,
   output [AXI_VFIFO_DATA_WIDTH-1:0]  axi_wdata,
   output                           axi_wvalid,
   input                            axi_wready,
   output [AXI_VFIFO_DATA_WIDTH/8-1:0]axi_wstrb,

   // AXI MM Read Data Interface
   input                            axi_rlast,
   input  [AXI_VFIFO_DATA_WIDTH-1:0]  axi_rdata,
   input                            axi_rvalid,
   output                           axi_rready,
   input  [AXI_VFIFO_DATA_WIDTH/8-1:0]axi_rstrb,
   input  [1:0]                     axi_rresp,  
    //- System interface
  input [AWIDTH-1:0]                start_address,
  input [AWIDTH-1:0]                end_address,
  input [8:0]                       wr_burst_size,
  input [8:0]                       rd_burst_size,
  
  input                             mcb_clk,
  input                             mcb_rst,
`endif

  input                             wr_reset_n, 
  input                             rd_reset_n  
);

  localparam REM_WIDTH = (AXIS_TDATA_WIDTH == 64) ? 3 : 4;

  wire [AXIS_TDATA_WIDTH-1:0]   axis_wr_tdata;
  wire                          axis_wr_tvalid;
  wire                          axis_wr_tready;

  wire [AXIS_TDATA_WIDTH-1:0]   axis_rd_tdata;
  wire                          axis_rd_tvalid;
  wire                          axis_rd_tready;
  
  /*
   *  Instance of control word inserter or the depacketizer module
   */
  control_word_insert #(
     .AXIS_TDATA_WIDTH      (AXIS_TDATA_WIDTH ),
     .STRB_WIDTH            (AXIS_TDATA_WIDTH/8),
     .REM_WIDTH             (REM_WIDTH        )
  ) U_CWI(
     .rst_n                 (wr_reset_n       ),  
     // AXI-ST interface before Control Word Insertion
     .axi_str_aclk          (axis_wr_aclk     ),
     .cwi_axi_str_tdata_in  (axi_str_wr_tdata ),
     .cwi_axi_str_tvalid_in (axi_str_wr_tvalid),
     .cwi_axi_str_tlast_in  (axi_str_wr_tlast ),
     .cwi_axi_str_tready_out(axi_str_wr_tready),
     .cwi_axi_str_tuser_in  (axi_str_wr_tuser ),
     // AXI-ST MINIMAL interface after Control Word Insertion
     .cwi_axi_str_tdata_out (axis_wr_tdata),
     .cwi_axi_str_tvalid_out(axis_wr_tvalid),
     .cwi_axi_str_tready_in (axis_wr_tready)
  );
  
`ifdef USE_DDR3_FIFO
  `ifdef VERIF
    vfifo_controller_verif #(
  `else
    vfifo_controller #(
  `endif
      .DWIDTH                             (DWIDTH                 ),
      .AWIDTH                             (AWIDTH                 ),
      .ID_WIDTH                           (ID_WIDTH               ),
      .ISSUANCE_LEVEL                     (ISSUANCE_LEVEL         ),
      .AXI_VFIFO_DATA_WIDTH               (AXI_VFIFO_DATA_WIDTH   ),
      .TXCNTWIDTH                         (CNTWIDTH               ),
      .RXCNTWIDTH                         (CNTWIDTH               )
    ) vfifo_ctrl_inst (
     .wr_clk                              (axis_wr_aclk           ),
     .rd_clk                              (axis_rd_aclk           ),
     .mcb_clk                             (mcb_clk                ),
     .rst_n                               (~mcb_rst               ),
     .wr_reset_n                          (wr_reset_n             ),
     .rd_reset_n                          (rd_reset_n             ),
     .start_addr                          (start_address          ),
     .end_addr                            (end_address            ),
     .wrburst_size                        (wr_burst_size          ),
     .rdburst_size                        (rd_burst_size          ),
     // interface to AXI MM write address port
     .p0_axi_awid                         (axi_awid            ),
     .p0_axi_awaddr                       (axi_awaddr          ),
     .p0_axi_awlen                        (axi_awlen           ),
     .p0_axi_awsize                       (axi_awsize          ),
     .p0_axi_awburst                      (axi_awburst         ),
     .p0_axi_awlock                       (axi_awlock          ),
     .p0_axi_awcache                      (axi_awcache         ),
     .p0_axi_awprot                       (axi_awprot          ),
     .p0_axi_awqos                        (axi_awqos           ),
     .p0_axi_awvalid                      (axi_awvalid      ),
     .p0_axi_awready                      (axi_awready      ),
     // interface to AXI MM read address port
     .p0_axi_arid                         (axi_arid            ),
     .p0_axi_araddr                       (axi_araddr          ),
     .p0_axi_arlen                        (axi_arlen           ),
     .p0_axi_arsize                       (axi_arsize          ),
     .p0_axi_arburst                      (axi_arburst         ),
     .p0_axi_arlock                       (axi_arlock          ),
     .p0_axi_arcache                      (axi_arcache         ),
     .p0_axi_arprot                       (axi_arprot          ),
     .p0_axi_arqos                        (axi_arqos           ),
     .p0_axi_arvalid                      (axi_arvalid      ),
     .p0_axi_arready                      (axi_arready      ),

   // interface to AXI MM write address response port
//     .p0_axi_bid                          (axi_bid             ),
     .p0_axi_bresp                        (axi_bresp           ),
     .p0_axi_bvalid                       (axi_bvalid       ),
     .p0_axi_bready                       (axi_bready       ),
     // register interface-error status
     .p0_axi_wr_error                     (     ),
     .p0_axi_rd_error                     (     ),

   // AXI Async FIFO Interface
     .p0_axi_str_wr_tdata                 (axis_wr_tdata    ),
     .p0_axi_str_wr_tvalid                (axis_wr_tvalid),
     .p0_axi_str_wr_tready                (axis_wr_tready),

   // AXI MM Write Data Interface
     .p0_axi_wlast                        (axi_wlast        ),              
     .p0_axi_wdata                        (axi_wdata           ),
     .p0_axi_wvalid                       (axi_wvalid       ),
     .p0_axi_wready                       (axi_wready       ),
     .p0_axi_wstrb                        (axi_wstrb           ),
    // AXI Async FIFO Interface
     .p0_axi_str_rd_tdata                 (axis_rd_tdata    ),
     .p0_axi_str_rd_tvalid                (axis_rd_tvalid),
     .p0_axi_str_rd_tready                (axis_rd_tready),
     .rd_data_count                       (rd_data_cnt  ),
     .wr_data_count                       (wr_data_cnt  ),
     .ddr3_fifo_empty                     (ddr3_fifo_empty ),
   // AXI MM Read Data Interface
     .p0_axi_rlast                        (axi_rlast        ),              
     .p0_axi_rdata                        (axi_rdata           ),
     .p0_axi_rvalid                       (axi_rvalid       ),
     .p0_axi_rready                       (axi_rready       ),
     .p0_axi_rstrb                        (axi_rstrb           ),
     .p0_axi_rresp                        (axi_rresp           )
     ); 
`else

  axis_async_fifo U_AXI_FIFO(
     .s_aresetn             (~sys_rst              ),
     .s_aclk                (axis_wr_aclk          ),
     .s_axis_tready         (axis_wr_tready        ),
     .s_axis_tvalid         (axis_wr_tvalid        ),
     .s_axis_tdata          (axis_wr_tdata         ),
     .m_aclk                (axis_rd_aclk          ),
     .m_axis_tready         (axis_rd_tready        ),
     .m_axis_tvalid         (axis_rd_tvalid        ),
     .m_axis_tdata          (axis_rd_tdata         ),
     .axis_prog_full_thresh ((2**(CNTWIDTH-1)) -1  ),
     .axis_rd_data_count    (rd_data_cnt           ),
     .axis_wr_data_count    (wr_data_cnt           )
  );

`endif


  /*
   *  Instance of control word strip or the packetizer module
   */
  control_word_strip #(
     .AXIS_TDATA_WIDTH      (AXIS_TDATA_WIDTH ),
     .STRB_WIDTH            (AXIS_TDATA_WIDTH/8),
     .REM_WIDTH             (REM_WIDTH        )
  ) U_CWS(
     .rst_n                 (rd_reset_n       ),  
     // AXI-ST MINIMAL interface before Control Word Stripping
     .cws_axi_str_tdata_in  (axis_rd_tdata    ),
     .cws_axi_str_tvalid_in (axis_rd_tvalid   ),
     .cws_axi_str_tready_out(axis_rd_tready   ),
     // AXI-ST interface after Contorl Word Stripping
     .cws_axi_str_tdata_out (axi_str_rd_tdata ),
     .cws_axi_str_tkeep_out (axi_str_rd_tkeep ),
     .cws_axi_str_tlast_out (axi_str_rd_tlast ),
     .cws_axi_str_tvalid_out(axi_str_rd_tvalid),
     .cws_axi_str_tready_in (axi_str_rd_tready),  
     .axi_str_aclk          (axis_rd_aclk     ),
     .cws_axi_str_tuser_out (axi_str_rd_tuser )
    );

endmodule
