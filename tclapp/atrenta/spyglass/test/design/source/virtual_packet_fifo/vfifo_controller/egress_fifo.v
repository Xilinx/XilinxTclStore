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
// This module performs read operation to read data from Memory controller. It
// asserts read enable as long as there is atleast one data word is available in
// read FIFO. It asserts a read request to command port control module whenever 
// read FIFO is empty and there are no read commands in pipe.

`timescale 1ps/1ps

module egress_fifo  #(
    parameter DWIDTH = 32,
    parameter AXI_VFIFO_DATA_WIDTH = 64,
    parameter ISSUANCE_LEVEL = 2,
    parameter RXCNTWIDTH = 9 
    )
    (
   
   input                            wr_clk,               // FIFO write clock input
   input                            rd_clk,               // FIFO read clock input 
   input                            rst_n,                  // Sync reset input

   // AXI Async FIFO Interface
   output  [DWIDTH-1:0]             p0_axi_str_rd_tdata,  // AXI FIFO data output
   output                           p0_axi_str_rd_tvalid, // AXI FIFO data valid
   input                            p0_axi_str_rd_tready, // AXI FIFO ready 
   
   // AXI Memory Mapped Interface
   input                            p0_axi_rlast,         // AXI MM last read data           
   input [AXI_VFIFO_DATA_WIDTH-1:0]   p0_axi_rdata,       // AXI MM read data
   input                            p0_axi_rvalid,        // AXI MM read data valid
   output                           p0_axi_rready,        // AXI MM read ready
   input [AXI_VFIFO_DATA_WIDTH/8-1:0] p0_axi_rstrb,         // AXI MM read strobe
   input [1:0]                      p0_axi_rresp,         // AXI MM read response
   
   // Control & Address Generation logic Interface 
   input                            rd_ready,             // Command on AXI MM read address bud
   output                           rd_data_done,         // Read data done
   output                           rd_full,              // RX Buffer full
   output [1:0]                     RD_RRESP,             // Read response output 
   input  [8:0]                     RD_LEN,               // Read burst length
   output reg [RXCNTWIDTH - 1:0]    rd_count,             // RX Buffer data count 
   output [RXCNTWIDTH-1:0]          rd_data_count,
   output [8:0]                     rd_burst_cnt,
   input                            rd_subopt,   
   input  [8:0]                     rdburst_size
   );
// Internal signals

reg [8:0]               user_burst_cnt;
reg                     err_latch;
reg [ISSUANCE_LEVEL-1:0]rd_tracker = 'd0;

wire [RXCNTWIDTH - 1:0] rx_wr_buff_count;

wire                    axis_prog_full;            // async_fifo programmable full threshold reached

  assign rd_burst_cnt = user_burst_cnt;

  always @(posedge wr_clk)
    if (rst_n==1'b0)
      rd_tracker  <= 'd0;
    else if (rd_data_done & ~rd_ready)
      rd_tracker  <= {1'b0,rd_tracker[ISSUANCE_LEVEL-1:1]};
    else if (rd_ready & ~rd_data_done)
      rd_tracker  <= {rd_tracker[ISSUANCE_LEVEL-2:0], 1'b1};

  // RX Buffer Instantiation
  // This is a coregen created asynchronous AXI-ST FIFO that is 64 bits wide and
  // 1024 locations deep.Data from External Memory is written into it 
  // using the // write enable signal, and a enable from read port
  // control sends this data to DMA

  // Programmable threshold FIFO is used here. RXCNTWIDTH that comes in 
  // is decremented by 1 and FIFO threshold is set as 2**(RXCNTWIDTH-1)-1 
  // just to be compliant with AXI stream FIFO that gives axis_wr/rd_data_count
  // with an extra bit to account for the roll over condition
//(* keep_hierarchy = "yes" *) axis_async_fifo rd_preview 
axis_async_fifo rd_preview 
(
  .m_aclk                 (rd_clk                ), // input m_aclk
  .s_aclk                 (wr_clk                ), // input s_aclk
  .s_aresetn              (rst_n                 ), // input s_aresetn
  .s_axis_tvalid          (p0_axi_rvalid         ), // input s_axis_tvalid
  .s_axis_tready          (p0_axi_rready         ), // output s_axis_tready
  .s_axis_tdata           (p0_axi_rdata          ), // input [63 : 0] s_axis_tdata
  .m_axis_tvalid          (p0_axi_str_rd_tvalid  ), // output m_axis_tvalid
  .m_axis_tready          (p0_axi_str_rd_tready  ), // input m_axis_tready
  .m_axis_tdata           (p0_axi_str_rd_tdata   ), // output [63 : 0] m_axis_tdata
  .axis_prog_full_thresh  ((2**(RXCNTWIDTH-1)) -1),
  .axis_wr_data_count     (rx_wr_buff_count      ), // output [12 : 0] axis_wr_data_count
  .axis_rd_data_count     (rd_data_count         ), // output [12 : 0] axis_rd_data_count
  .axis_prog_full         (axis_prog_full        )
);

  assign rd_full       = ~p0_axi_rready || axis_prog_full;
  assign rd_data_done  = p0_axi_rlast & p0_axi_rvalid & p0_axi_rready;
  assign RD_RRESP      = err_latch ? 2'b10 : 2'b00;

  always @ (posedge wr_clk)
      rd_count      <= rx_wr_buff_count;

  always @ (posedge wr_clk)
  begin
    if (rst_n==1'b0)
      user_burst_cnt <= 0;
    else if (rd_ready & rd_subopt)
      user_burst_cnt <= RD_LEN;  // load this value
    else if ((user_burst_cnt == 0) & (|rd_tracker))  
      user_burst_cnt <= rdburst_size;
    else if (p0_axi_rvalid & p0_axi_rready) 
      if (user_burst_cnt != 'd0)
        user_burst_cnt <= user_burst_cnt - 1'b1;
      else
        user_burst_cnt <= 'd0;
  end     

 // In AXI read interface p0_axi_rresp comes along with every data, accumulate the
 // Read responses for the Burst length equal to RD_LEN and report to command control 
 // block if there is a non-zero p0_axi_rresp.
 always @ (posedge wr_clk)
    if (rst_n==1'b0)
      err_latch <= 0;
    else if ((p0_axi_rresp != 2'b00) & (user_burst_cnt != 'd0))
      err_latch <= 1'b1;
    else if (rd_ready) 
      err_latch <= 1'b0;


endmodule 

