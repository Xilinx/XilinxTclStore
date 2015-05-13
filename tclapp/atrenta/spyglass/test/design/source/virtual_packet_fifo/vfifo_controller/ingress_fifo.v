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
// Description of module:
// This module performs write operation to AXI MCB using the AXI Memory Mapped
// Write data Interface. It sends data equal to the Burst length decided by command 
// control module on the AXI MM Bus. AXI MM Write address bus send ready signal only 
// after it receives data equal to Burst length issued on address bus.

`timescale 1ps/1ps


module ingress_fifo #(
   parameter DWIDTH = 32,                          // Width of the write data port
   parameter AXI_VFIFO_DATA_WIDTH = 64,
   parameter ISSUANCE_LEVEL = 2,
   parameter MAX_CNT_WIDTH = 12,
   parameter TXCNTWIDTH = 9                        // TX Buffer depth is 2**9 i.e. 512
   
    )
    (
   
   input                            wr_clk,               // FIFO write clock input
   input                            rd_clk,               // FIFO read clock input 
   input                            rst_n,                  // Sync reset input

   // AXI Async FIFO Interface
   input  [DWIDTH-1:0]              p0_axi_str_wr_tdata,  // AXI FIFO data
   input                            p0_axi_str_wr_tvalid, // AXI FIFO data valid
   output                           p0_axi_str_wr_tready, // AXI FIFO ready 
   
   // AXI Memory Mapped Interface
   output                           p0_axi_wlast,         // AXI MM last write data                    
   output [AXI_VFIFO_DATA_WIDTH-1:0]  p0_axi_wdata,         // AXI MM write data
   output                           p0_axi_wvalid,        // AXI MM write data valid
   input                            p0_axi_wready,        // AXI MM ready from slave
   output [AXI_VFIFO_DATA_WIDTH/8-1:0]p0_axi_wstrb,         // AXI MM write strobe             
   
   // Control & Address Generation logic Interface 
   input                            wr_ready,             // Command on AXI MM write address bus
   input  [8:0]                     WR_LEN,               // Burst length of write command
   output                           wr_empty,             // TX Buffer empty
   output reg [TXCNTWIDTH - 1:0]    wr_count,             // TX Buffer data count
   output [8:0]                     wr_burst_cnt,         // Current burst size
   output reg                       wlast_done,           // wlast_done signal
   input                            wr_issued,            // Signal indicating issued write
   input                            wr_subopt,            // Suboptimal burst indicator
   output [TXCNTWIDTH-1:0]          wr_data_count,
   input [8:0]                      wrburst_size          // Write burst size when burst size is not suboptimal   
   );
   
 
reg  [8:0]              user_burst_cnt = 0;        // pre loaded down counter
reg                     read_fifo = 0;             // Internal TX Buffer read enable
reg [ISSUANCE_LEVEL-1:0]wr_tracker = 'd0;
reg                     override_read_fifo = 1'b0;

wire [TXCNTWIDTH- 1:0] tx_rd_buff_count;          // TX Buffer data count
wire                    wr_data_done;              // wr_data_done signal
wire                    p0_axi_wready_i;
wire                    p0_axi_wvalid_i;

wire                    axis_prog_full;            // async_fifo programmable full threshold reached

  //- Keep track of issuance levels for write
  always @(posedge rd_clk)
    if (rst_n==1'b0)
      wr_tracker  <= 'd0;
    else if (wr_data_done & ~wr_ready )
      wr_tracker  <= {1'b0,wr_tracker[ISSUANCE_LEVEL-1:1]};
    else if (wr_ready & ~p0_axi_wlast)
      wr_tracker  <= {wr_tracker[ISSUANCE_LEVEL-2:0],1'b1};

  assign wr_burst_cnt = user_burst_cnt;

  always @(posedge rd_clk)
  begin
    wlast_done  <= wr_data_done;
  end

  // TX Buffer Instantiation
  // This is a coregen created asynchronous AXI-ST FIFO that is 64 bits wide and
  // 1024 locations deep.Data from DMA is written into it using the
  // write enable signal, and a enable from write port control reads
  // this data

  // Programmable threshold FIFO is used here. TXCNTWIDTH that comes in 
  // is decremented by 1 and FIFO threshold is set as 2**(TXCNTWIDTH-1)-1 
  // just to be compliant with AXI stream FIFO that gives axis_wr/rd_data_count
  // with an extra bit to account for the roll over condition

//(* keep_hierarchy = "yes" *) axis_async_fifo wr_preview 
axis_async_fifo wr_preview 
(
  .m_aclk                 (rd_clk                ), // input m_aclk
  .s_aclk                 (wr_clk                ), // input s_aclk
  .s_aresetn              (rst_n                 ), // input s_aresetn
  .s_axis_tvalid          (p0_axi_str_wr_tvalid  ), // input s_axis_tvalid
  .s_axis_tready          (p0_axi_str_wr_tready  ), // output s_axis_tready
  .s_axis_tdata           (p0_axi_str_wr_tdata   ), // input [63 : 0] s_axis_tdata
  .m_axis_tvalid          (p0_axi_wvalid_i       ), // output m_axis_tvalid
  .m_axis_tready          (p0_axi_wready_i       ), // input m_axis_tready
  .m_axis_tdata           (p0_axi_wdata          ), // output [63 : 0] m_axis_tdata
  .axis_prog_full_thresh  ((2**(TXCNTWIDTH-1)) -1),
  .axis_wr_data_count     (wr_data_count         ), // output [12 : 0] axis_wr_data_count
  .axis_rd_data_count     (tx_rd_buff_count      ), // output [12 : 0] axis_rd_data_count
  .axis_prog_full         (axis_prog_full        )
);

  assign p0_axi_wready_i = p0_axi_wready & (read_fifo | override_read_fifo);
  
  // Output assignments
  assign p0_axi_wstrb     = {AXI_VFIFO_DATA_WIDTH/8{1'b1}};// All bytes valid in every data


  assign p0_axi_wlast = (user_burst_cnt == 'd1);    
  assign wr_empty  = ~p0_axi_wvalid_i;
  assign wr_data_done  = p0_axi_wlast & p0_axi_wvalid & p0_axi_wready;
  assign p0_axi_wvalid = p0_axi_wvalid_i & (read_fifo | override_read_fifo);

  always @(posedge rd_clk)
      wr_count  <= tx_rd_buff_count; 

  // override_read_fifo is asserted only when write packet length is 1
  always @(posedge rd_clk)
    if (wr_ready & (WR_LEN == 1))
      override_read_fifo  <= wr_ready;
    else
      override_read_fifo  <= 1'b0;


  // Asserted high on wr_ready assertion & De-asserted only after the WR_LEN equal data
  // sent on the AXI MM interface
  always @ (posedge rd_clk)
    if (rst_n==1'b0)
      read_fifo <= 0;
    else if (user_burst_cnt == 'd1 & p0_axi_wready & p0_axi_wvalid)
        read_fifo <= 1'b0;
    else if (|wr_tracker) 
      read_fifo <= 1'b1;

  // Down counter to track the number of data words sent on AXI MM write data bus
  always @( posedge rd_clk)
  begin
    if (rst_n==1'b0)
      user_burst_cnt <= 'd0;
    else if (wr_ready & wr_subopt)
      user_burst_cnt <= WR_LEN;
    else if ((user_burst_cnt == 'd0) & |wr_tracker & ~wr_subopt)
      user_burst_cnt <= wrburst_size;
    else if (p0_axi_wvalid & p0_axi_wready) 
      if (user_burst_cnt != 'd0)
        user_burst_cnt <= user_burst_cnt - 1'b1;
      else
        user_burst_cnt <= 'd0;
  end     

endmodule 
