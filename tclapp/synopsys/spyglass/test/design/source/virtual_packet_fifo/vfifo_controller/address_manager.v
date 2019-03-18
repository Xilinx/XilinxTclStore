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
// This module generates address, burst length and instructions for the Memory 
// controller based on the control signals from read/write_port_control modules.
// It also tracks the data/space available in the DDR3 memory before issuing 
// read/write command so that data overwritten can be avoided.
// Burst data can be written in two ways: full burst and sub-optimal burst. Suboptimal
// burst is enabled when data available to be written/read from is less than burst
// length.   

`timescale 1ps/1ps

module address_manager # (
  parameter AWIDTH   = 32,
  parameter DWIDTH   = 32,
  parameter AXI_VFIFO_DATA_WIDTH = 64,
  parameter ISSUANCE_LEVEL = 2,
  parameter RXCNTWIDTH = 9,
  parameter TXCNTWIDTH = 9,
  parameter ID_WIDTH = 4
  )
  ( 
   input                   clk,               // Clock input
   input                   rst_n,             // Sync rst_n input
   input [31:0]            start_addr,        // DDR3 start address (user defined)
   input [31:0]            end_addr,          // DDR3 end address (user defined)
   input [8:0]             wrburst_size,      // AXI-MM write burst length (user defined 1-256)
   input [8:0]             rdburst_size,      // AXI-MM read burst length (user defined 1-256)
   
   // interface to AXI MM write address port
   output [ID_WIDTH-1:0]   p0_axi_awid,
   output reg [AWIDTH-1:0] p0_axi_awaddr,
   output reg [7:0]        p0_axi_awlen,
   output [2:0]            p0_axi_awsize,
   output [1:0]            p0_axi_awburst,
   output [1:0]            p0_axi_awlock,
   output [3:0]            p0_axi_awcache,
   output [2:0]            p0_axi_awprot,
   output [3:0]            p0_axi_awqos,
   output reg              p0_axi_awvalid,
   input                   p0_axi_awready,

   // interface to AXI MM read address port
   output [ID_WIDTH-1:0]   p0_axi_arid,
   output reg [AWIDTH-1:0] p0_axi_araddr,
   output reg [7:0]        p0_axi_arlen,
   output [2:0]            p0_axi_arsize,
   output [1:0]            p0_axi_arburst,
   output [1:0]            p0_axi_arlock,
   output [3:0]            p0_axi_arcache,
   output [2:0]            p0_axi_arprot,
   output [3:0]            p0_axi_arqos,
   output reg              p0_axi_arvalid,
   input                   p0_axi_arready,
   
   // interface to AXI MM write address response port
   input  [1:0]            p0_axi_bresp,
   input                   p0_axi_bvalid,
   output reg              p0_axi_bready,
  
   // register interface-error status
   output                  p0_axi_wr_error,
   output                  p0_axi_rd_error,

   // interface to write data port
   output reg [8:0]        WR_LEN,
   input  [TXCNTWIDTH-1:0] wr_count,
   input                   wr_empty,
   output reg              wr_ready,
   output reg              wr_subopt = 1'b0,
   output reg              rd_subopt = 1'b0,

   // interface to read data port
   output reg [8:0]        RD_LEN,
   input  [1:0]            RD_RRESP,
   input  [RXCNTWIDTH-1:0] rd_count,
   input                   rd_full,
   output reg              rd_ready,
   input                   rd_data_done,
   input                   wlast_done,
   input [8:0]             wr_burst_cnt,
   input [8:0]             rd_burst_cnt,
   output                  wr_issued,

   // DDR3 FIFO status
   output reg              ddr3_fifo_empty 
   );
  
localparam  
  `ifdef SIMULATION
            WR_INIT = 0, 
  `endif          
            WR_IDLE = 1,
            ISSUE_AW  = 2,
            WAIT_AWDONE = 3,
            WAIT_WDONE  = 4,
            WAIT_W_0  = 5,
            WAIT_W_1  = 6,
            CHECK_WR_ISSUANCE = 7;
            

localparam  
            RD_IDLE = 1,
            ISSUE_AR = 2,
            WAIT_ARDONE = 3,
            WAIT_RDONE  = 4,
            WAIT_R_0  = 5,
            WAIT_R_1  = 6,
            CHECK_RD_ISSUANCE = 7;
          
localparam NUM_BYTES = AXI_VFIFO_DATA_WIDTH/8;

parameter DDR_TIMEOUT  = 400;
parameter FIFO_TIMEOUT = 400;
localparam NUM_DATA_CNT = (AXI_VFIFO_DATA_WIDTH == 256) ? 5 : 
                          (AXI_VFIFO_DATA_WIDTH == 128) ? 4 :
                          (AXI_VFIFO_DATA_WIDTH == 64)  ? 3 : 2;

wire         xfer_wr_cmd;          // Transfer write command to AXI-MCB
wire         xfer_rd_cmd;          // Transfer read command to AXI-MCB
wire         load_start_addr_wr;   // Load start address
wire         load_start_addr_rd;   // Load start address
wire         wr_enable;            // Enable signal for Write FSM
wire         rd_enable;            // Enable signal for Read FSM
wire         rd_issued; 
wire         wr_end_addr_range;    // Asserted when next write burst to be transferred exceeds programmed end address 
wire         rd_end_addr_range;    // Asserted when next read burst to be transferred exceeds programmed end address
wire         force_current_avl_burst_wr;
wire         force_current_avl_burst_rd;
wire         force_burst_size_wr; 
wire         force_burst_size_rd;  

wire [31:0]  ddr3_wr_space_left2_wrap;
wire [31:0]  ddr3_rd_space_left2_wrap;

reg  [3:0]   wr_current_state;     // Current state (write)
reg  [3:0]   rd_current_state;     // Current state (read)

reg [31:0]   WR_BYTE_CNT = 'd0;    // Write burst length in bytes (actual to AXI-MCB)
reg [31:0]   RD_BYTE_CNT = 'd0;    // Read burst length in bytes (actual to AXI-MCB)
reg [TXCNTWIDTH-1:0] wr_count_to_use='d0;
reg [RXCNTWIDTH-1:0] rd_count_to_use='d0;

//- Signals to track completion of AW and AR transactions issue
reg aw_done=1'b0;
reg ar_done=1'b0;
reg  [31:0] wr_addr_counts;       // Write address counter 
reg  [31:0] rd_addr_counts;       // Read address counter

/* 
   Read and write issuance trackers
   Based on issuance level selected during compile time, these trackers
   keep track of requests issued
*/   
reg [ISSUANCE_LEVEL-1:0]  wr_tracker = 'd0;
reg [ISSUANCE_LEVEL-1:0]  rd_tracker = 'd0;
//- Read and write byte counters
reg [31:0] wr_counter   = 'd0;
reg [31:0] rd_counter   = 'd0;
reg [31:0] rd_counter_r = 'd0;
reg [31:0] ddr3_data_avlble = 'd0;       // Data available in DDR3 memory 

//- DDR3 data and space availability for a given burst size
//  Comparison is done in bytes
reg ddr3_data_eql_bl = 1'b0;
reg ddr3_space_eql_bl = 1'b0; 
//- intermediate status flags
reg wr_data_avlbl = 'd0;       
reg rd_space_avlbl = 'd0;       
reg wrap_wr_adrs = 1'b0;
reg wrap_rd_adrs = 1'b0;

//- Timeout counters and associated flags for read and write
reg wr_timeout = 1'b0;
reg [11:0] wr_to_count = 'd0;
reg rd_timeout = 1'b0;
reg [11:0] rd_to_count = 'd0;
reg wr_reached_tc = 1'b0;
reg mask_wr_subopt_gen = 1'b0;
reg rd_reached_tc = 1'b0;
reg [8:0] wr_subopt_burst = 'd0;
reg [8:0] rd_subopt_burst = 'd0;
reg [31:0] current_ddr3_space = 'd0;
reg [TXCNTWIDTH-1:0] wr_count_r; 


//- Timeout count definitions for issuance of sub-optimal burst lengths
//- Can be made programmable by software if required
`ifdef SIMULATION
  localparam WR_TIMEOUT_TC = 250;
  localparam RD_TIMEOUT_TC = 150;
`else
  localparam WR_TIMEOUT_TC = 500;
  localparam RD_TIMEOUT_TC = 400;
`endif

  /* 
      * DDR3 is empty is asserted in the following cases
      * o When Ingress FIFO has no data to be read out
      * o All DDR3 data are read out
      * o wr_counter count has reached zero
  */
  always @(posedge clk)
  begin
      ddr3_fifo_empty <= (wr_count == 0) & (ddr3_data_avlble ==0) & (wr_counter==0); 
  end
 
  //- Generate AW/AR done flags, register for better timing
  always @(posedge clk)
  begin
    aw_done <= p0_axi_awvalid & p0_axi_awready;
    ar_done <= p0_axi_arvalid & p0_axi_arready;
  end

  /*
     * Enable timeout when 
     *  o state is IDLE
     *  o there are no pending transactions (trackers are cleared)
     *  o there is residual data in write preview FIFO or residual data to
     *    be read from DDR3 FIFO
  */
  always @(posedge clk)
  begin
    //-Write timeout enable
    if ((wr_current_state == WR_IDLE) && (wr_count != 0) & (wr_tracker == 0))
      wr_timeout  <= 1'b1;
    else
      wr_timeout  <= 1'b0;

    //-Read timeout enable
    if ((rd_current_state == RD_IDLE) && (rd_counter != 0) & (rd_tracker == 0))
      rd_timeout  <= 1'b1;
    else
      rd_timeout  <= 1'b0;
  end
  
  //- Start timeout counter when enable is asserted
  always @(posedge clk)
  begin
    if (~wr_timeout)
      wr_to_count <= 'd0;
    else if (wr_timeout)
      wr_to_count <= wr_to_count + 1'b1;
  end

  //- Start timeout counter when enable is asserted
  always @(posedge clk)
  begin
    if (~rd_timeout)
      rd_to_count <= 'd0;
    else if (rd_timeout)
      rd_to_count <= rd_to_count + 1'b1;
  end

  //- Assert the terminal timeout count flag - the terminal value is
  //  decided based on experiments for the respective application
  always @(posedge clk)
  begin
    wr_reached_tc <= (wr_to_count == WR_TIMEOUT_TC);
    rd_reached_tc <= (rd_to_count == RD_TIMEOUT_TC);
  end   

  //- Currently available space in DDR3 in bytes
  //- wr_counter gives a count of already written burst 
  //- end_addr-start_addr gives the total space allocated in ddr3
  //- Available space= Total space - Already written bytes  
  always @(posedge clk)
    if((end_addr - start_addr) >= wr_counter)
       current_ddr3_space  <= ((end_addr - start_addr) - wr_counter);
 
  /*
     *  Transactions issued due to timeout fall under suboptimal burst size
     *  category. Assert necessary flags and for writes, the residual data
     *  in preview FIFO is the burst size and for reads, residual data in
     *  DDR3 FIFO is the burst size.
     *  Also make sure DDR3 has enough space to hold the suboptimal burst
     *  size without wrapping around of address.
     *  Sub-optimal burst is enabled when address is wrapping around and 
        data to be written/read from exceeds the end address
  */

  // mask_wr_subopt_gen masks wr_enable until write response from AXI-IC is received
  // This is essential because WR_BYTE_CNT needs to reflect in house-keeper for rd_counter 
  always @(posedge clk)
   if (rst_n==1'b0)
       mask_wr_subopt_gen <= 1'b0;
   else if(aw_done)
       mask_wr_subopt_gen <= 1'b1;
   else if(p0_axi_bvalid & p0_axi_bready)
       mask_wr_subopt_gen <= 1'b0;

  //- The maximum burst size that can be written/read out at any time is wrburst_size   //- or the rdburst_size. 
  always @(posedge clk)
     wr_count_to_use <= (wr_count>=wrburst_size)?wrburst_size:wr_count; 

  always @(posedge clk)
     rd_count_to_use <= (ddr3_data_avlble>=rdburst_size)?rdburst_size:ddr3_data_avlble; 

  //- When address count reaches end address range, the difference between end address
  //- and current address count should be written/read out from FIFO.
  assign   force_current_avl_burst_wr = force_burst_size_wr & wr_data_avlbl & ddr3_space_eql_bl ;

  assign   force_current_avl_burst_rd = force_burst_size_rd & (rd_tracker == 0) ;

  assign force_burst_size_wr =  (wr_count_to_use >= ddr3_wr_space_left2_wrap) & (wr_count_to_use>0) & (wr_current_state==WR_IDLE);

  assign force_burst_size_rd = (rd_count_to_use>=ddr3_rd_space_left2_wrap) & (rd_count_to_use>0) & (rd_current_state == RD_IDLE) ;

  // For better timing on wr_count, use wr_count_r for suboptimal 
  always @(posedge clk)
      wr_count_r <= wr_count ;
  
  assign  ddr3_wr_space_left2_wrap =   (end_addr -wr_addr_counts) >> NUM_DATA_CNT;

  assign  ddr3_rd_space_left2_wrap =   (end_addr -rd_addr_counts) >> NUM_DATA_CNT;

  // Suboptimal write burst generation
  always @(posedge clk)
    if (rst_n==1'b0)
    begin
      wr_subopt <= 1'b0;
      wr_subopt_burst  <= 'd0;
    end
    else if (wr_current_state == WAIT_WDONE)
    begin
      wr_subopt <= 1'b0;
      wr_subopt_burst  <= 'd0;
    end
    else if (force_current_avl_burst_wr)
    begin
      wr_subopt <= 1'b1;
      wr_subopt_burst  <= ddr3_wr_space_left2_wrap;
    end
    else if (wr_reached_tc & ((current_ddr3_space >> NUM_DATA_CNT)>0) & (wr_current_state==WR_IDLE))
    begin
      wr_subopt <= 1'b1;
      wr_subopt_burst  <=   (wr_count_r >= wrburst_size) ? wrburst_size : 
                            (wr_count_r > (current_ddr3_space >> NUM_DATA_CNT)) ?
                            (current_ddr3_space >> NUM_DATA_CNT) : wr_count_r;
    end
  
  // Suboptimal read burst generation
  always @(posedge clk)
    if (rst_n==1'b0)
    begin
      rd_subopt <= 1'b0;
      rd_subopt_burst <= 'd0;
    end
    else if (rd_current_state == WAIT_RDONE)
    begin
      rd_subopt <= 1'b0;
      rd_subopt_burst <= 'd0;
    end
    else if (force_current_avl_burst_rd)
    begin
      rd_subopt <= 1'b1;
      rd_subopt_burst  <= ddr3_rd_space_left2_wrap;
    end
    else if (rd_reached_tc & (rd_current_state == RD_IDLE) & (rd_tracker==0))
    begin
      rd_subopt <= 1'b1;
      rd_subopt_burst <= (ddr3_data_avlble >= rdburst_size) ? rdburst_size :
                         ddr3_data_avlble;
    end
  
  /*
      Shift register tracker for keeping track of issuance levels
      On wlast_done, clear it one bit - indicating completion of one level
      On aw_done, set it one bit - indicating issuance of one level
  */
  always @(posedge clk)
    if (rst_n==1'b0)
      wr_tracker  <= 'd0;
    else if (wlast_done & ~aw_done)
      wr_tracker  <= {1'b0,wr_tracker[ISSUANCE_LEVEL-1:1]};
    else if (aw_done & ~wlast_done)
      wr_tracker  <= {wr_tracker[ISSUANCE_LEVEL-2:0], 1'b1};

  assign wr_issued  = |wr_tracker;

  //- Byte counts keep track of bytes written/read during each transaction
  always @(posedge clk)
    if (xfer_wr_cmd)
      WR_BYTE_CNT  <= wr_subopt ? NUM_BYTES*(wr_subopt_burst) : 
                      NUM_BYTES*(wrburst_size);

  /*
      Shift register tracker for keeping track of acceptance levels
      On rd_data_done, clear it one bit - indicating completion of one level
      On ar_done, set it one bit - indicating acceptance of one level
  */
  always @(posedge clk)
    if (rst_n==1'b0)
      rd_tracker  <= 'd0;
    else if (rd_data_done & ~ar_done)
      rd_tracker  <= {1'b0,rd_tracker[ISSUANCE_LEVEL-1:1]};
    else if (ar_done & ~rd_data_done)
      rd_tracker  <= {rd_tracker[ISSUANCE_LEVEL-2:0], 1'b1};

  assign rd_issued  = |rd_tracker;
 
  /*
   *  RD_BYTE_CNT should be reverted to the max burst length once
   *  rlast is received for suboptimal case. Otherwise, if during
   *  suboptimal read, a write happens, a potential suboptimal read can be
   *  issued in succession without waiting for read timeout.
  */
  always @(posedge clk)
    if (xfer_rd_cmd)
      RD_BYTE_CNT   <= rd_subopt ? NUM_BYTES*(rd_subopt_burst) :
                                   NUM_BYTES*(rdburst_size);

  /*
     * Write counter to track write space available in DDR3 for write logic
     * This counter is checked before issuing any newer write requests.
     *  o Increments on issue of AW transaction, which indicates write
     *    given
     *  o Decrements when rlast is received which implies data is read out
  */
  always @ (posedge clk)
  begin
    if (rst_n==1'b0)
      wr_counter <= 'b0;
    else if (aw_done & rd_data_done)
      wr_counter <= wr_counter + WR_BYTE_CNT - RD_BYTE_CNT;
    else if (aw_done)
      wr_counter <= wr_counter + WR_BYTE_CNT;
    else if (rd_data_done)
      wr_counter <= wr_counter - RD_BYTE_CNT;
    end

  /*
   * Read Counter to count the data available in DDR3 for read logic
   * This counter is checked before issuing newer read transactions.
   *  o Increments on write response reception for an issued write
   *    transaction
   *    o Issued write transaction is acknowledged by bvalid and bready coming
          from AXI-IC     
   *  o Decrements on issue of AR
  */
  always @ (posedge clk)
  begin
    if (rst_n==1'b0)
      rd_counter <= 'b0;
    else if ((p0_axi_bvalid & p0_axi_bready) & ar_done)
      rd_counter <= rd_counter + WR_BYTE_CNT - RD_BYTE_CNT;
    else if (p0_axi_bvalid & p0_axi_bready)
      rd_counter <= rd_counter + WR_BYTE_CNT;
    else if (ar_done)
      rd_counter <= rd_counter - RD_BYTE_CNT;
    end

  // Convert bytes to number of data words (AXI4-MM interface data width)  
  always @(posedge clk)
     ddr3_data_avlble <= rd_counter >>  NUM_DATA_CNT;

  // Compare read and write pointers to DDR3, to get the space/data available
  // information. These signals are later qualified in read_enable and write_enable
  // generation for read and write FSM
  always @(posedge clk)
  begin
    ddr3_data_eql_bl  = (rd_counter != 0) & (rd_counter >= RD_BYTE_CNT);
    ddr3_space_eql_bl = (current_ddr3_space >= NUM_BYTES*(wrburst_size)); 
  end

  /*
     * Track write data count available in preview FIFO 
     *  o For suboptimal case and force burst condition, assumed that 
     *    data is available as the suboptimal timeout is 
     *    enabled only when there is residual data in write preview FIFO
   */
  always @(posedge clk)
    if (wr_empty | !rst_n)
      wr_data_avlbl <= 1'b0;
    else if (~(wr_reached_tc | force_burst_size_wr))
    begin
        if (wr_issued)
          wr_data_avlbl <= ((wr_count >= wrburst_size) & (wr_burst_cnt==0));
        else  
          wr_data_avlbl <= (wr_count >= wrburst_size);
    end
    else 
      wr_data_avlbl <= 1'b1;

  /*
    - Enable write when following conditions are met-
      o Preview FIFO has enough data for issuing AW
      o DDR3 has space to hold one burst of data
      o Suboptimal request generation is asserted
  */
  assign wr_enable = wr_data_avlbl & ddr3_space_eql_bl & !mask_wr_subopt_gen;

  // Write address generation
  // address counts get incremented by burst_length issued in bytes 
  always @ (posedge clk)
  begin
    if (rst_n==1'b0)
      wr_addr_counts <= start_addr;
    else if (aw_done | load_start_addr_wr)
      if (load_start_addr_wr)
        wr_addr_counts <= start_addr; 
      else if(aw_done & !wr_end_addr_range)
        wr_addr_counts <= wr_addr_counts + WR_BYTE_CNT;
  end

  // wr_end_addr_range is issued when next address + number of bytes written
  // exceeds the end address programmed
  assign wr_end_addr_range = ((wr_addr_counts + WR_BYTE_CNT) >= end_addr);

  /*
     * Track read data space available in preview FIFO 
     *  o For suboptimal case, space should be available but check it to
     *    make sure
  */
  always @(posedge clk)
    if (rd_full | !rst_n)
      rd_space_avlbl <= 1'b0;
    else if (~(rd_reached_tc | force_burst_size_rd))
    begin
        if (rd_issued)
          rd_space_avlbl <= ((({RXCNTWIDTH{1'b1}} - rd_count) - rd_burst_cnt) >= rdburst_size);
        else  
          rd_space_avlbl <= (({RXCNTWIDTH{1'b1}} - rd_count) >= rdburst_size);
    end
    else 
      rd_space_avlbl  <= (({RXCNTWIDTH{1'b1}} - rd_count) >= rd_subopt_burst);

  // rd_counter needs to be registered and used in rd_enable generation as rd_subopt
  // is generated one cycle after terminal count is reached or burst count is forced
  always @(posedge clk)
        rd_counter_r <= rd_counter;

  assign rd_enable = rd_subopt ? rd_space_avlbl : 
                     (rd_counter_r >= (NUM_BYTES * rdburst_size)) ?
                     rd_space_avlbl & ddr3_data_eql_bl & !force_burst_size_rd:1'b0;

  // Read address generation
  // address counts get incremented by burst_length and port size each rd command generated
  always @ (posedge clk)
    begin
    if (rst_n==1'b0)
      rd_addr_counts <= start_addr;
    else if (ar_done | load_start_addr_rd) 
      if (load_start_addr_rd)
        rd_addr_counts <= start_addr;
      else if(ar_done & !rd_end_addr_range)
        rd_addr_counts <=  rd_addr_counts + RD_BYTE_CNT;
    end

  // wr_end_addr_range is issued when next address + number of bytes written
  // exceeds the end address programmed
  assign rd_end_addr_range = ((rd_addr_counts + RD_BYTE_CNT) >= end_addr);

  //- Flag off wrapping so that after issue of current AW, it loads the
  //start address
  always @(posedge clk)
    if (load_start_addr_wr)
      wrap_wr_adrs  <= 1'b0;
    else if ((wr_current_state == WAIT_AWDONE) &  wr_end_addr_range)
      wrap_wr_adrs  <= 1'b1;

  assign load_start_addr_wr = wrap_wr_adrs ; 

  //- Flag off wrapping so that after issue of current AR, it loads the
  //start address
  always @(posedge clk)
    if (load_start_addr_rd)
      wrap_rd_adrs  <= 1'b0;
    else if ((rd_current_state == WAIT_ARDONE) &  rd_end_addr_range)
      wrap_rd_adrs  <= 1'b1;
      
  assign load_start_addr_rd = wrap_rd_adrs ;

  // Output assignments
  assign p0_axi_wr_error = 1'b0;
  assign p0_axi_rd_error = 1'b0;

  assign p0_axi_awid    = 4'b0000;      //- IDs overwritten at top level
  assign p0_axi_awsize  = NUM_DATA_CNT;
  assign p0_axi_awburst = 2'b01;    // Incrementing burst
  assign p0_axi_awlock  = 2'b00;    // Normal access
  assign p0_axi_awcache = 4'b0011;  // Enable data packing   
  assign p0_axi_awprot  = 3'b000;
  assign p0_axi_awqos   = 4'b0000;

  assign p0_axi_arid    = 4'b0000;    //- IDs overwritten at top level
  assign p0_axi_arsize  = NUM_DATA_CNT;
  assign p0_axi_arburst = 2'b01;    // Incrementing burst
  assign p0_axi_arlock  = 2'b00;    // Normal access
  assign p0_axi_arcache = 4'b0011;  // Enable data packing
  assign p0_axi_arprot  = 3'b000;
  assign p0_axi_arqos   = 4'b0000;

  //- Issue write transaction
  always @ (posedge clk)
  begin
    if ((rst_n==1'b0) | (p0_axi_awvalid & p0_axi_awready))
      begin
      p0_axi_awaddr   <= 0;
      p0_axi_awvalid  <= 0;
      p0_axi_awlen    <= 0; 
      end
    else if (xfer_wr_cmd)
      begin
      p0_axi_awaddr   <= wr_addr_counts;
      p0_axi_awvalid  <= 1'b1;
      p0_axi_awlen    <= wr_subopt ? (wr_subopt_burst - 1'b1) : 
                                      (wrburst_size - 1'b1); 
      end
  end

  //- Issue read transaction
  always @ (posedge clk)
  begin
    if ((rst_n==1'b0) | (p0_axi_arvalid & p0_axi_arready))
      begin
      p0_axi_araddr   <= 0;
      p0_axi_arvalid  <= 0;
      p0_axi_arlen    <= 0; 
      end
    else if (xfer_rd_cmd)
      begin
      p0_axi_araddr   <= rd_addr_counts;
      p0_axi_arvalid  <= 1'b1;
      p0_axi_arlen    <= rd_subopt ? rd_subopt_burst - 1'b1 :
                                    rdburst_size - 1'b1; 
      end
  end

  //- Always ready to receive write response
  always @ (posedge clk)
      p0_axi_bready <= 1'b1;

  // Acknowledge output assignments to read/write requests
  always @ (posedge clk)
    if ((rst_n==1'b0) | wr_ready)
      begin
      wr_ready <= 0;
      WR_LEN   <= 0;
      end
    else if (xfer_wr_cmd) 
      begin
      wr_ready <= 1'b1;
      WR_LEN   <= wr_subopt ? wr_subopt_burst : wrburst_size; 
      end

  always @ (posedge clk)
    if ((rst_n==1'b0) | rd_ready)
      begin
      rd_ready <= 0;
      RD_LEN   <= 0;
      end
    else if (xfer_rd_cmd)
      begin
      rd_ready <= 1'b1;
      RD_LEN   <= rd_subopt ? rd_subopt_burst : rdburst_size;
      end

`ifdef SIMULATION

  //- Timeout logic for WR_INIT
  /*    
      If the packet is really small compared to count used in WR_INIT,
      simulation will get stuck. Avoid that by using a timeout counter
   */

  reg  [6:0]    wr_init_to;
  wire          move_out_of_init;

  initial wr_init_to = 7'd50;

  always @(posedge clk)
    if (~wr_empty & (wr_current_state == WR_INIT))
      wr_init_to  <= wr_init_to - 1'b1;

  assign move_out_of_init = (wr_init_to == 7'd0);

`endif


  // FSM for Write Transaction Logic
  always @ (posedge clk)
    if (rst_n==1'b0)
  `ifdef SIMULATION
      wr_current_state <= WR_INIT;  
  `else
    wr_current_state <= WR_IDLE;
  `endif
    else
    case (wr_current_state)
      /*
          State defined only for simulation to simulate address pipelining
      */
  `ifdef SIMULATION
      WR_INIT:  
              if ((wr_count >= 'd32) | move_out_of_init)
                wr_current_state <= WR_IDLE;
              else
                wr_current_state <= WR_INIT;
  `endif               
      /*
       * Idle state
          o Move to issue AW if there is no address wraparound
          o Move to wrap state if end address is reached
      */
      WR_IDLE :
            if (wr_enable)
              wr_current_state <= ISSUE_AW;
            else
              wr_current_state <= WR_IDLE;

      /*
       *  Issues AW transaction with precomputed burst/length size
      */
      ISSUE_AW:
                wr_current_state <= WAIT_AWDONE;

      /*

          o if not, move to check for issuance levels for address
            pipelining  
      */
      WAIT_AWDONE:
                if (aw_done & wr_subopt)
                  wr_current_state  <= WAIT_WDONE;
                else if (aw_done)
                  wr_current_state <= WAIT_W_0;
                else  
                  wr_current_state <= WAIT_AWDONE;
      /*
       *  This state waits for wlast for the previously issued transaction.
       *  This is reached only in cases where suboptimal bursts are issued.
      */
      WAIT_WDONE: 
                if (wlast_done)
                  wr_current_state  <= CHECK_WR_ISSUANCE;
                else
                  wr_current_state  <= WAIT_WDONE;
      /*
       * The wait state is added so that DDR3 space available for write can be 
       * updated based on wr_counter value
      */
      WAIT_W_0:
                wr_current_state <= WAIT_W_1;

      /*
       * The wait state is added so that DDR3 space available for write can be 
       * updated based on wr_counter value
      */
      WAIT_W_1:
                wr_current_state <= CHECK_WR_ISSUANCE;

      /*
       * This state checks for current issuance level based on tracker and
       * waits if all issuance levels are consumed.
      */
      CHECK_WR_ISSUANCE:
                if (~(&wr_tracker))
                  wr_current_state <= WR_IDLE;
                else
                  wr_current_state <= CHECK_WR_ISSUANCE;
      default: wr_current_state  <= WR_IDLE;                  
    endcase

  //- Instruction to transfer write command - issues AW
  assign xfer_wr_cmd = (wr_current_state == ISSUE_AW);

  //- Instruction to transfer read command - issues AR
  assign xfer_rd_cmd = (rd_current_state == ISSUE_AR);

  //- FSM for read transaction logic
  always @(posedge clk)
    if (rst_n==1'b0)
      rd_current_state  <= RD_IDLE;
    else
      case (rd_current_state)
        /*
         *  Idle state
              o Move to issue AR if there is no address wraparound
              o Move to wrap state if end address is reached
        */
        RD_IDLE:
                if (rd_enable)
                  rd_current_state  <= ISSUE_AR;
                else
                  rd_current_state  <= RD_IDLE;

        /*
         *  Issues AR transaction with precomputed burst/length size
        */
        ISSUE_AR:
                rd_current_state  <= WAIT_ARDONE;
       /*
        * State waiting for AR transaction done (ready and valid handshake)
          o if this is a suboptimal transaction, move to state where it
            waits for rlast 
          o if not, move to check for issuance levels for address
            pipelining  
        */
        WAIT_ARDONE:
                if (ar_done & rd_subopt)
                  rd_current_state <= WAIT_RDONE;
                else if (ar_done)
                  rd_current_state  <= WAIT_R_0;
                else
                  rd_current_state  <= WAIT_ARDONE;
       /*
        *  This state waits for rlast for the previously issued transaction.
        *  This is reached only in cases where suboptimal bursts are issued.
        */
        WAIT_RDONE: 
                if (rd_data_done)
                  rd_current_state  <= CHECK_RD_ISSUANCE;
                else
                  rd_current_state  <= WAIT_RDONE;

        /*
         * The wait state is added so that DDR3 data available for write can be 
         * updated based on rd_counter value
        */
        WAIT_R_0:
                rd_current_state <= WAIT_R_1;

        /*
         * The wait state is added so that DDR3 data available for write can be 
         * updated based on rd_counter value
        */
        WAIT_R_1:
                rd_current_state <= CHECK_RD_ISSUANCE;

         /*
          * This state checks for current issuance level based on tracker and
          * waits if all issuance levels are consumed.
         */
         CHECK_RD_ISSUANCE:
                if (~(&rd_tracker))
                  rd_current_state <= RD_IDLE;
                else
                  rd_current_state <= CHECK_RD_ISSUANCE;
        default:
                  rd_current_state <= RD_IDLE;
      endcase

endmodule 
