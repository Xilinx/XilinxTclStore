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
//
// Monitors the PCIe AXI interface to keep track of byte count sent/received during
// a one second time period.  Last two bits of byte count are dropped and replaced
// with a 2-bit sample count indicating that sample period to which the information
// belongs.  Software will read the registers every second, and will group together
// data from the same sample count.
//
`timescale 1ps / 1ps
(* CORE_GENERATION_INFO = "k7_pcie_dma_ddr3_base,k7_pcie_dma_ddr3_base_trd_v1_6,{pcie_performance_monitor=2013.2}" *)
module pcie_performance_monitor
#( parameter DWIDTH = 64)
 (
   input                 clk,
   input                 reset,
   input        [7:0]    clk_period_in_ns,
   
   // - PCIe-AXI TX interface
   input [DWIDTH-1:0]    s_axis_tx_tdata,
   input                 s_axis_tx_tlast,
   input                 s_axis_tx_tvalid,
   input                 s_axis_tx_tready,
   input [3:0]           s_axis_tx_tuser,
   
   // - PCIe-AXI RX interface
   input [DWIDTH-1:0]    m_axis_rx_tdata,
   input                 m_axis_rx_tlast,
   input                 m_axis_rx_tvalid,
   input                 m_axis_rx_tready,

   input       [11:0]    fc_cpld,
   input       [7:0]     fc_cplh,
   input       [11:0]    fc_npd,
   input       [7:0]     fc_nph,
   input       [11:0]    fc_pd,
   input       [7:0]     fc_ph,
   output      [2:0]     fc_sel,
   
   output reg  [11:0]    init_fc_cpld,
   output reg  [7:0]     init_fc_cplh,
   output reg  [11:0]    init_fc_npd,
   output reg  [7:0]     init_fc_nph,
   output reg  [11:0]    init_fc_pd,
   output reg  [7:0]     init_fc_ph,


   output reg  [31:0]    tx_byte_count,
   output reg  [31:0]    rx_byte_count,
   output reg  [31:0]    tx_payload_count,
   output reg  [31:0]    rx_payload_count

);

   
   reg [DWIDTH-1 : 0]   reg_tx_tdata;
   reg                  reg_tx_tlast;
   reg                  reg_tx_tstart;
   reg                  reg_tx_tvalid;
   reg                  reg_tx_tdsc;
   reg                  reg_tx_tready;
                        
   reg [DWIDTH-1 : 0]   reg_rx_tdata;
   reg                  reg_rx_tlast;
   reg                  reg_rx_tstart;
   reg                  reg_rx_tvalid;
   reg                  reg_rx_tready;
   
   reg                  expect_tx_tstart;
   reg                  expect_rx_tstart;
   
   reg [9:0]            tx_dw_len; 
   reg [6:0]            tx_tlp_type;
   reg [9:0]            rx_dw_len; 
   reg [6:0]            rx_tlp_type;
   
   reg [31:0]           tx_byte_count_int;
   reg [31:0]           rx_byte_count_int;
   reg [31:0]           tx_payload_count_int;
   reg [31:0]           rx_payload_count_int;

   reg  [1:0]     sample_cnt;
   
   parameter [6:0] MEMWR3DW = 7'b10_00000,
                   MEMWR4DW = 7'b11_00000,
                   MEMRD3DW = 7'b00_00000,
                   MEMRD4DW = 7'b01_00000,
                   CPL      = 7'b00_01010,
                   CPLD     = 7'b10_01010,
                   
                   // generic information
                   MEMWR    = 7'b1?_00000,
                   MEMRD    = 7'b0?_00000,
                   CPLTN    = 7'b?0_01010;
 
   parameter NUM_ST_BITS = 3;
   
   parameter [NUM_ST_BITS - 1 : 0] 
      IDLE     = 'h0,
      GOT_HDR1 = 'h1,
      GOT_HDR2 = 'h2,
      GOT_HDR3 = 'h3,
      DATA     = 'h4;
      
   reg [NUM_ST_BITS - 1 : 0] tx_curr_state, tx_next_state;
   reg [NUM_ST_BITS - 1 : 0] rx_curr_state, rx_next_state;
   
   reg [1:0]   capture_count;
   reg         captured_initfc;
 
   
   // Timer controls
   reg  [30:0]    running_test_time;
   wire [30:0]    one_second_cnt;

   // Only taking into account 125 MHz and 250 MHz
   assign one_second_cnt = (clk_period_in_ns == 4) ? 'hEE6B280 : 'h7735940;
   
   always @(posedge clk)   
   begin
   
      if (reset == 1'b1) begin
          reg_tx_tdata           <= 'h0;
          reg_tx_tlast       <= 'b0;
          reg_tx_tvalid   <= 'b0;
          reg_tx_tdsc   <= 'b0;
          reg_tx_tready   <= 'b0;
          
          reg_rx_tdata           <= 'h0;
          reg_rx_tlast       <= 'b0;
          reg_rx_tvalid   <= 'b0;
          reg_rx_tready   <= 'b0;

      end else begin
      
          reg_tx_tdata           <= s_axis_tx_tdata;
          reg_tx_tlast       <= s_axis_tx_tlast;
          reg_tx_tvalid   <= s_axis_tx_tvalid;
          reg_tx_tdsc   <= s_axis_tx_tuser[3];
          reg_tx_tready   <= s_axis_tx_tready;
          
          reg_rx_tdata           <= m_axis_rx_tdata;
          reg_rx_tlast       <= m_axis_rx_tlast;
          reg_rx_tvalid   <= m_axis_rx_tvalid;
          reg_rx_tready   <= m_axis_rx_tready;
      
      end
   
   end

  always @(posedge clk)
  begin
  
    if (reset == 1'b1  | (reg_tx_tlast == 1'b1 & reg_tx_tvalid == 1'b1 & reg_tx_tready == 1'b1))
      expect_tx_tstart <= 1'b1;
    else if (expect_tx_tstart == 1'b1 & reg_tx_tvalid == 1'b1 & reg_tx_tready == 1'b1)
      expect_tx_tstart <= 1'b0;
  end
  
  always @(expect_tx_tstart,reg_tx_tvalid,reg_tx_tready) begin
    reg_tx_tstart   <= expect_tx_tstart & reg_tx_tvalid & reg_tx_tready;
  end
  
  always @(posedge clk)
  begin
  
    if (reset == 1'b1  | (reg_rx_tlast == 1'b1 & reg_rx_tvalid == 1'b1 & reg_rx_tready == 1'b1))
      expect_rx_tstart <= 1'b1;
    else if (expect_rx_tstart == 1'b1 & reg_rx_tvalid == 1'b1 & reg_rx_tready == 1'b1)
      expect_rx_tstart <= 1'b0;
  end
  
  always @(expect_rx_tstart,reg_rx_tvalid,reg_rx_tready) begin
    reg_rx_tstart   <= expect_rx_tstart & reg_rx_tvalid & reg_rx_tready;
  end

   // TX monitor state machine.  Keeps track of whether we are in header or in data portion of TLP. 
   always @(tx_curr_state, reg_tx_tstart, reg_tx_tlast, reg_tx_tvalid, reg_tx_tready, tx_tlp_type)
   begin: TX_FSM_COMB
   
      case (tx_curr_state)
      
      IDLE: begin
         
         if (reg_tx_tstart == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1) 
         
            tx_next_state <= GOT_HDR1;
            
         else
         
            tx_next_state <= IDLE;
            
      end
      
      GOT_HDR1: begin
         
         if (reg_tx_tlast == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1)
         
            tx_next_state <= IDLE;
            
         else if (reg_tx_tvalid == 1'b1 && DWIDTH == 64)
         
            tx_next_state <= DATA;
            
         else if (reg_tx_tvalid == 1'b1 && DWIDTH == 32)
            
            tx_next_state <= GOT_HDR2;
            
         else 
         
            tx_next_state <= GOT_HDR1;
      
      end
      
      GOT_HDR2: begin
         
         if (reg_tx_tlast == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1)
         
            tx_next_state <= IDLE;
            
         else if (reg_tx_tvalid == 1'b1 && tx_tlp_type[5] == 1'b1)  // 64-bit addressing
            
            tx_next_state <= GOT_HDR3;
            
         else if (reg_tx_tvalid == 1'b1)
            
            tx_next_state <= DATA;

         else 
         
            tx_next_state <= GOT_HDR2;
      
      end

      GOT_HDR3: begin
         
         if (reg_tx_tlast == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1)
         
            tx_next_state <= IDLE;
            
         else if (reg_tx_tvalid == 1'b1)
            
            tx_next_state <= DATA;

         else 
         
            tx_next_state <= GOT_HDR3;
      
      end

     
      DATA: begin

         if (reg_tx_tlast == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1)
         
            tx_next_state <= IDLE;
            
         else
         
            tx_next_state <= DATA;
            
      end
      
      default: begin

         tx_next_state <= IDLE;
      
      end
      
      endcase
   
   end


   // RX monitor state machine.  Keeps track of whether we are in header or in data portion of TLP.
   always @(rx_curr_state, reg_rx_tstart, reg_rx_tlast, reg_rx_tvalid, reg_rx_tready, rx_tlp_type)
   begin: RX_FSM_COMB
   
      case (rx_curr_state)
      
      IDLE: begin
         
         if (reg_rx_tstart == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1) 
         
            rx_next_state <= GOT_HDR1;
            
         else
         
            rx_next_state <= IDLE;
            
      end
      
      GOT_HDR1: begin
         
         if (reg_rx_tlast == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1)
         
            rx_next_state <= IDLE;
            
         else if (reg_rx_tvalid == 1'b1 && DWIDTH == 64)
         
            rx_next_state <= DATA;
            
         else if (reg_rx_tvalid == 1'b1 && DWIDTH == 32)
            
            rx_next_state <= GOT_HDR2;
            
         else 
         
            rx_next_state <= GOT_HDR1;
      
      end
      
      GOT_HDR2: begin
         
         if (reg_rx_tlast == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1)
         
            rx_next_state <= IDLE;
            
         else if (reg_rx_tvalid == 1'b1 && rx_tlp_type[6] == 1'b1)  // 64-bit addressing
            
            rx_next_state <= GOT_HDR3;
            
         else if (reg_rx_tvalid == 1'b1)
            
            rx_next_state <= DATA;

         else 
         
            rx_next_state <= GOT_HDR2;
      
      end

      GOT_HDR3: begin
         
         if (reg_rx_tlast == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1)
         
            rx_next_state <= IDLE;
            
         else if (reg_rx_tvalid == 1'b1)
            
            rx_next_state <= DATA;

         else 
         
            rx_next_state <= GOT_HDR3;
      
      end

     
      DATA: begin

         if (reg_rx_tlast == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1)
         
            rx_next_state <= IDLE;
            
         else
         
            rx_next_state <= DATA;
            
      end
      
      default: begin

         rx_next_state <= IDLE;
      
      end
      
      endcase
   
   end


// Keep track of time during test
always @(posedge clk)
begin: TIMER_PROC

   if (reset == 1'b1) begin
   
       running_test_time <= 'h0;
       sample_cnt <= 'h0;
       
   end else if (running_test_time == 'h0) begin
       
       running_test_time <= one_second_cnt;
       sample_cnt <= sample_cnt + 1'b1;
       
   end else begin
       running_test_time <= running_test_time - 1'b1;
       sample_cnt <= sample_cnt;

   end
end

// Concatenate sample_cnt with byte count at end of sample period.
always @(posedge clk)
begin: COPY_PROC

   if (reset == 1'b1) begin
   
      tx_byte_count     <= 'h0;
      rx_byte_count     <= 'h0;
      tx_payload_count  <= 'h0;
      rx_payload_count  <= 'h0;
       
   end else if (running_test_time == 'h0) begin
       
      tx_byte_count     <= {tx_byte_count_int[31:2], sample_cnt}   ;
      rx_byte_count     <= {rx_byte_count_int[31:2], sample_cnt}   ;
      tx_payload_count  <= {tx_payload_count_int[31:2], sample_cnt};
      rx_payload_count  <= {rx_payload_count_int[31:2], sample_cnt};
       
   end
end

// Synchronous part of state machine, and logic to grab length and type of TLP
// on the AXI interface.
always @(posedge clk)
begin
   if (reset == 1'b1) begin
       tx_curr_state <= IDLE;
       rx_curr_state <= IDLE;
       
       tx_dw_len     <= 'h0;
       tx_tlp_type   <= 'h0;
       
       rx_dw_len     <= 'h0;
       rx_tlp_type   <= 'h0;


     end else begin

       // State machine controls TX
       if (reg_tx_tdsc == 1'b1)
       
          tx_curr_state <= IDLE;
          
       else if (reg_tx_tready == 1'b1)
       
          tx_curr_state <= tx_next_state;


       // State machine controls RX
       if (reg_rx_tready == 1'b1)
       
          rx_curr_state <= rx_next_state;
    
          
       
       // Grab TX Header information
       if (reg_tx_tstart == 1'b1 && reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1 ) begin
       
          tx_dw_len   <= reg_tx_tdata[9:0];
          tx_tlp_type <= reg_tx_tdata[30:24];
       
       end

       // Grab RX Header information
       if (reg_rx_tstart == 1'b1 && reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1 ) begin
       
          rx_dw_len   <= reg_rx_tdata[9:0];
          rx_tlp_type <= reg_rx_tdata[30:24];
          
       
       end
       
   end // else
end // always


// Logic to calculate raw byte count (all TLPs including headers) and 
// payload (MEMWR and CPLD data only) byte count.
always @(posedge clk)
begin
   if (reset == 1'b1 || running_test_time == 'h0) begin

      tx_byte_count_int     <= 'h0;
      rx_byte_count_int     <= 'h0;
      tx_payload_count_int  <= 'h0;
      rx_payload_count_int  <= 'h0;
     
     end else begin
   
       casex (tx_tlp_type)
       MEMWR:
         if (reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1) begin
       
            // count data at end of header for 32-bit address MemWr
            if (tx_curr_state == GOT_HDR1 && DWIDTH == 64 && tx_tlp_type[5] == 1'b0) 
         
               tx_payload_count_int <= tx_payload_count_int + 4;
         
            // just count payload
            else if (tx_curr_state == DATA) 
       
               tx_payload_count_int <= tx_payload_count_int + DWIDTH/8;

         end
       
       endcase
       
       // Count all bytes when a transaction is active
       if (reg_tx_tvalid == 1'b1 && reg_tx_tready == 1'b1) begin
       
          tx_byte_count_int <= tx_byte_count_int + DWIDTH/8;

       end 
           
       casex (rx_tlp_type)
       CPLD:
         if (reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1) begin
       
           // count data at end of header for completion
           if (rx_curr_state == GOT_HDR1 && DWIDTH == 64) 
         
              rx_payload_count_int <= rx_payload_count_int + 4;
         
           // just count payload
           else if (rx_curr_state == DATA) 
       
              rx_payload_count_int <= rx_payload_count_int + DWIDTH/8;

         end 
       endcase
            
       // Count all bytes when a transaction is active
       if (reg_rx_tvalid == 1'b1 && reg_rx_tready == 1'b1) begin
       
          rx_byte_count_int <= rx_byte_count_int + DWIDTH/8;

       end 

    end // reset not active
end // process

// synthesis translate_off
reg [8*12:0] tx_fsm_name, rx_fsm_name;


always @(tx_curr_state)
begin

  case (tx_curr_state)
      IDLE    : tx_fsm_name <= "IDLE    ";
      GOT_HDR1: tx_fsm_name <= "GOT_HDR1";
      GOT_HDR2: tx_fsm_name <= "GOT_HDR2";
      GOT_HDR3: tx_fsm_name <= "GOT_HDR3";
      DATA    : tx_fsm_name <= "DATA    ";
      default : tx_fsm_name <= "ILLEGAL ";
  endcase
  
end

always @(rx_curr_state)
begin

  case (rx_curr_state)
      IDLE    : rx_fsm_name <= "IDLE    ";
      GOT_HDR1: rx_fsm_name <= "GOT_HDR1";
      GOT_HDR2: rx_fsm_name <= "GOT_HDR2";
      GOT_HDR3: rx_fsm_name <= "GOT_HDR3";
      DATA    : rx_fsm_name <= "DATA    ";
      default : rx_fsm_name <= "ILLEGAL ";
  endcase
  
end
// synthesis translate_on


// Capturing Initfc values on the Host System

always @(posedge clk) begin
  if (reset == 1'b1 ) 
    captured_initfc <= 1'b0;
  else if (capture_count == 'h3) 
    captured_initfc <= 1'b1;
    
  if (capture_count == 'h3) begin
    init_fc_cpld   <=  fc_cpld;
    init_fc_cplh   <=  fc_cplh;
    init_fc_npd    <=  fc_npd;
    init_fc_nph    <=  fc_nph; 
    init_fc_pd     <=  fc_pd;  
    init_fc_ph     <=  fc_ph;  
  end

  if (reset == 1'b0 && captured_initfc == 1'b0) 
    capture_count <= capture_count + 1'b1;
  else  
    capture_count <= 'h0;
end

assign fc_sel = (captured_initfc) ? 3'b000 : 3'b101; 


endmodule

