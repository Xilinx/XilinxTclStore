// -------------------------------------------------------------------------
//
//  PROJECT: PCI Express Core
//  COMPANY: Northwest Logic, Inc.
//
// ------------------------- CONFIDENTIAL ----------------------------------
//
//                 Copyright 2006 by Northwest Logic, Inc.
//
//  All rights reserved.  No part of this source code may be reproduced or
//  transmitted in any form or by any means, electronic or mechanical,
//  including photocopying, recording, or any information storage and
//  retrieval system, without permission in writing from Northest Logic, Inc.
//
//  Further, no use of this source code is permitted in any form or means
//  without a valid, written license agreement with Northwest Logic, Inc.
//
//                         Northwest Logic, Inc.
//                  1100 NW Compton Drive, Suite 100
//                      Beaverton, OR 97006, USA
//
//                       Ph.  +1 503 533 5800
//                       Fax. +1 503 533 5900
//                          www.nwlogic.com
//
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
//
// This module implements example logic to illustrate use of the DMA Back-End
//   Target Write and Target Read Interfaces; all target access from the DMA
//   Back-End are terminated by this module; this module implements only
//   one target memory and does not use the targ_wr_cs and targ_rd_cs chip
//   seclects; if multiple BARs are implemented, they will all map to the
//   same RAM in this module
//
// -------------------------------------------------------------------------

`timescale 1ps / 1ps



// -----------------------
// -- Module Definition --
// -----------------------

module register_map # (
parameter REG_ADDR_WIDTH = 32, 
parameter CORE_DATA_WIDTH = 64,
parameter CORE_BE_WIDTH = CORE_DATA_WIDTH/8
)
(

  input                               rst_n,
  input                               clk,

  input                               awvalid,
  output                              awready,
  input       [31:0]                  awaddr,
  input       [3:0]                   awlen,
  input       [2:0]                   awregion,
  input       [2:0]                   awsize,

  input                               wvalid,
  output                              wready,
  input       [CORE_DATA_WIDTH-1:0]   wdata,
  input                               wlast,
  input       [CORE_BE_WIDTH-1:0]     wstrb,

  output reg                          bvalid = 0,
  input                               bready,
  output reg  [1:0]                   bresp = 0,

  input                               arvalid,
  output                              arready,
  input       [31:0]                  araddr,
  input       [3:0]                   arlen,
  input       [2:0]                   arregion,
  input       [2:0]                   arsize,

  output reg                          rvalid = 0,
  input                               rready,
  output reg  [CORE_DATA_WIDTH-1:0]   rdata = 0,
  output reg                          rlast = 0,
  output reg  [1:0]                   rresp = 0,

  // Raw Data Registers
  output reg                          enable_checker0 = 0,
  output reg                          enable_generator0 = 0,
  output reg                          enable_loopback0 = 0,
  output reg  [15:0]                  pkt_len0 = 'd768,
  input                               data_mismatch0,

  // Raw Data Registers
  output reg                          enable_checker1 = 0,
  output reg                          enable_generator1 = 0,
  output reg                          enable_loopback1 = 0,
  output reg  [15:0]                  pkt_len1 = 'd768,
  input                               data_mismatch1,
  
  // Virtual FIFO Controller registers
  input                               calib_done,
  input       [3:0]                   ddr3_fifo_empty,
  
  output reg                          axi_ic_mig_shim_rst_n = 1'b1,
  output reg  [31:0]                  start_addr_p0 = 32'h0000_0000,
  output reg  [31:0]                  end_addr_p0 = 32'h0700_0000,
  output reg  [8:0]                   wr_burst_size_p0 = 9'd256,
  output reg  [8:0]                   rd_burst_size_p0 = 9'd256,
  output reg  [31:0]                  start_addr_p1 = 32'h0800_0000,
  output reg  [31:0]                  end_addr_p1 = 32'h0F00_0000,
  output reg  [8:0]                   wr_burst_size_p1 = 9'd256,
  output reg  [8:0]                   rd_burst_size_p1 = 9'd256,
  output reg  [31:0]                  start_addr_p2 = 32'h1000_0000,
  output reg  [31:0]                  end_addr_p2 = 32'h1700_0000,
  output reg  [8:0]                   wr_burst_size_p2 = 9'd256,
  output reg  [8:0]                   rd_burst_size_p2 = 9'd256,
  output reg  [31:0]                  start_addr_p3 = 32'h1800_0000,
  output reg  [31:0]                  end_addr_p3 = 32'h1F00_0000,
  output reg  [8:0]                   wr_burst_size_p3 = 9'd256,
  output reg  [8:0]                   rd_burst_size_p3 = 9'd256,
  
  
  // Intial Flow Control Credits of the host system 
  input       [11:0]                  init_fc_cpld,
  input       [7:0]                   init_fc_cplh,
  input       [11:0]                  init_fc_npd,
  input       [7:0]                   init_fc_nph,
  input       [11:0]                  init_fc_pd,
  input       [7:0]                   init_fc_ph,
  
  // Monitor status/control registers               
  input       [31:0]                  tx_pcie_byte_count,
  input       [31:0]                  rx_pcie_byte_count,
  input       [31:0]                  tx_pcie_payload_count,
  input       [31:0]                  rx_pcie_payload_count   


);
//localparam  CORE_REMAIN_WIDTH       = 3;

parameter [15:0] // Design Versioning register
                 DESIGN_VERSION                         = 'h9000,
                 
                 // Design Status Register (0x9008)
                 DESIGN_STATUS                          = 'h9008,
                 
                 // PCIe Performance Monitor registers
                 MON_TX_PCIE_BYTE_COUNT                 = 'h900C,
                 MON_RX_PCIE_BYTE_COUNT                 = 'h9010,
                 MON_TX_PCIE_PAYLOAD_COUNT              = 'h9014,
                 MON_RX_PCIE_PAYLOAD_COUNT              = 'h9018,

                 MON_INIT_FC_CPLD                       = 'h901C,
                 MON_INIT_FC_CPLH                       = 'h9020,
                 MON_INIT_FC_NPD                        = 'h9024,
                 MON_INIT_FC_NPH                        = 'h9028,
                 MON_INIT_FC_PD                         = 'h902C,
                 MON_INIT_FC_PH                         = 'h9030,
                 
                 // 0x9100 - 0x91FF UserApp0 (Raw Packet data) registers
                 RAWDATA_ENABLE_GENERATOR0              = 'h9100,
                 RAWDATA_PKT_LEN0                       = 'h9104,
                 RAWDATA_ENABLE_LB_CHECKER0             = 'h9108,
                 RAWDATA_CHECKER_STATUS0                = 'h910C,
                 
                 // 0x9200 - 0x92FF UserApp1 (Raw Packet data) Registers
                 RAWDATA_ENABLE_GENERATOR1              = 'h9200,
                 RAWDATA_PKT_LEN1                       = 'h9204,
                 RAWDATA_ENABLE_LB_CHECKER1             = 'h9208,
                 RAWDATA_CHECKER_STATUS1                = 'h920C,

                 // 0x9300 - 0x93FF Virtual FIFO Controller Registers
                 START_ADDR_P0                          = 'h9300,
                 END_ADDR_P0                            = 'h9304,
                 WR_BURST_SIZE_P0                       = 'h9308,
                 RD_BURST_SIZE_P0                       = 'h930C,

                 START_ADDR_P1                          = 'h9310,
                 END_ADDR_P1                            = 'h9314,
                 WR_BURST_SIZE_P1                       = 'h9318,
                 RD_BURST_SIZE_P1                       = 'h931C,

                 START_ADDR_P2                          = 'h9320,
                 END_ADDR_P2                            = 'h9324,
                 WR_BURST_SIZE_P2                       = 'h9328,
                 RD_BURST_SIZE_P2                       = 'h932C,

                 START_ADDR_P3                          = 'h9330,
                 END_ADDR_P3                            = 'h9334,
                 WR_BURST_SIZE_P3                       = 'h9338,
                 RD_BURST_SIZE_P3                       = 'h933C;


reg     [15:0]                        reg_wr_addr;
reg                                   reg_wr_en;
reg     [CORE_BE_WIDTH-1:0]           reg_wr_be;
reg     [CORE_DATA_WIDTH-1:0]         reg_wr_data;
reg     [15:0]                        reg_rd_addr;
reg     [CORE_DATA_WIDTH-1:0]         reg_rd_data;


// Target Reads
wire                                  rd_en;
reg     [7:0]                         rd_count;
reg                                   read_valid;
reg                                   read_last;
reg                                   hold_valid;
reg     [CORE_DATA_WIDTH-1:0]         hold_data;
reg                                   hold_last;

// Target Writes
reg     [7:0]                         wr_count;
reg     [15:0]                        wr_addr;

reg     [7:0]                         clr_rst;


// Grab data from register write access and make available to rest of design.
always @(posedge clk)
begin
  if (rst_n == 1'b0) begin
    // default values for registers
    enable_generator0    <= 'h0;
    enable_generator1    <= 'h0;
   
  end else if (reg_wr_en) begin
      // register address ending in 0
      case (reg_wr_addr)
        DESIGN_STATUS               : axi_ic_mig_shim_rst_n <= reg_wr_data[1];

        RAWDATA_ENABLE_GENERATOR0   : enable_generator0     <= reg_wr_data[0];
        RAWDATA_ENABLE_LB_CHECKER0  : begin
                                      enable_checker0       <= reg_wr_data[0];
                                      enable_loopback0      <= reg_wr_data[1];
                                      end
        RAWDATA_ENABLE_GENERATOR1   : enable_generator1     <= reg_wr_data[0];
        RAWDATA_ENABLE_LB_CHECKER1  : begin
                                      enable_checker1       <= reg_wr_data[0];
                                      enable_loopback1      <= reg_wr_data[1];
                                      end

        START_ADDR_P0               : start_addr_p0         <= reg_wr_data[31:0];
        WR_BURST_SIZE_P0            : wr_burst_size_p0      <= reg_wr_data[8:0];
        START_ADDR_P1               : start_addr_p1         <= reg_wr_data[31:0];
        WR_BURST_SIZE_P1            : wr_burst_size_p1      <= reg_wr_data[8:0];
        START_ADDR_P2               : start_addr_p2         <= reg_wr_data[31:0];
        WR_BURST_SIZE_P2            : wr_burst_size_p2      <= reg_wr_data[8:0];
        START_ADDR_P3               : start_addr_p3         <= reg_wr_data[31:0];
        WR_BURST_SIZE_P3            : wr_burst_size_p3      <= reg_wr_data[8:0];

      // register address ending in 4
        RAWDATA_PKT_LEN0            : pkt_len0              <= reg_wr_data[(32+15):(32+0)];
        RAWDATA_PKT_LEN1            : pkt_len1              <= reg_wr_data[(32+15):(32+0)];

        END_ADDR_P0                 : end_addr_p0           <= reg_wr_data[(32+31):(32+0)];
        RD_BURST_SIZE_P0            : rd_burst_size_p0      <= reg_wr_data[(32+8):(32+0)];
        END_ADDR_P1                 : end_addr_p1           <= reg_wr_data[(32+31):(32+0)];
        RD_BURST_SIZE_P1            : rd_burst_size_p1      <= reg_wr_data[(32+8):(32+0)];
        END_ADDR_P2                 : end_addr_p2           <= reg_wr_data[(32+31):(32+0)];
        RD_BURST_SIZE_P2            : rd_burst_size_p2      <= reg_wr_data[(32+8):(32+0)];
        END_ADDR_P3                 : end_addr_p3           <= reg_wr_data[(32+31):(32+0)];
        RD_BURST_SIZE_P3            : rd_burst_size_p3      <= reg_wr_data[(32+8):(32+0)];
     
     endcase
  end

  // The register self clears after 9 clocks
  if (reg_wr_en != 1'b1) begin
    axi_ic_mig_shim_rst_n <= axi_ic_mig_shim_rst_n | clr_rst[7];
  end
  
end


always @(posedge clk)
begin
   if (axi_ic_mig_shim_rst_n)
      clr_rst <= 8'b0;
   else
      clr_rst <= {clr_rst[6:0], 1'b1};
end



wire [15:0] reg_rd_addr_000;
assign reg_rd_addr_000 = {reg_rd_addr[15:3], 3'b000};
wire [15:0] reg_rd_addr_100;
assign reg_rd_addr_100 = {reg_rd_addr[15:3], 3'b100};

// Provide data to Read Registers
always @(posedge clk)
begin
    // register address ending in 0
    case (reg_rd_addr_000)
       //32-bit read-only register 
       //[31:28]- Device  (0000)Artix-7, (0001)Kintex-7, (0010)Virtex-7, 
       //[11:4] - Version number matching zip version. Example for v1.2, it will be b'0001_0010(h'12)
       //[3:0]  - Subversion number  (0000) non-AXI design, (0001) AXI design
       //Other bits are reserved and return zero.
       DESIGN_VERSION               : reg_rd_data[31:0]     <= 32'h1108_0161;

       DESIGN_STATUS                : reg_rd_data[31:0]     <= {26'b0,ddr3_fifo_empty, axi_ic_mig_shim_rst_n, calib_done};

       MON_RX_PCIE_BYTE_COUNT       : reg_rd_data[31:0]     <= rx_pcie_byte_count;
       MON_RX_PCIE_PAYLOAD_COUNT    : reg_rd_data[31:0]     <= rx_pcie_payload_count;

       MON_INIT_FC_CPLH             : reg_rd_data[31:0]     <= {20'b0, init_fc_cplh};
       MON_INIT_FC_NPH              : reg_rd_data[31:0]     <= {20'b0, init_fc_nph};
       MON_INIT_FC_PH               : reg_rd_data[31:0]     <= {20'b0, init_fc_ph};

       RAWDATA_ENABLE_GENERATOR0    : reg_rd_data[31:0]     <= {31'b0, enable_generator0};
       RAWDATA_ENABLE_LB_CHECKER0   : reg_rd_data[31:0]     <= {30'b0, enable_loopback0, enable_checker0};

       RAWDATA_ENABLE_GENERATOR1    : reg_rd_data[31:0]     <= {31'b0, enable_generator1};
       RAWDATA_ENABLE_LB_CHECKER1   : reg_rd_data[31:0]     <= {30'b0, enable_loopback1, enable_checker1};

       START_ADDR_P0                : reg_rd_data[31:0]     <= start_addr_p0;         
       WR_BURST_SIZE_P0             : reg_rd_data[31:0]     <= {23'b0, wr_burst_size_p0};   
       START_ADDR_P1                : reg_rd_data[31:0]     <= start_addr_p1;        
       WR_BURST_SIZE_P1             : reg_rd_data[31:0]     <= {23'b0, wr_burst_size_p1};   
       START_ADDR_P2                : reg_rd_data[31:0]     <= start_addr_p2;        
       WR_BURST_SIZE_P2             : reg_rd_data[31:0]     <= {23'b0, wr_burst_size_p2};  
       START_ADDR_P3                : reg_rd_data[31:0]     <= start_addr_p3;        
       WR_BURST_SIZE_P3             : reg_rd_data[31:0]     <= {23'b0, wr_burst_size_p3};  

       default                      : reg_rd_data[31:0]     <= 32'b0; 
    endcase

    // register address ending in 4
    case (reg_rd_addr_100)
       MON_TX_PCIE_BYTE_COUNT       : reg_rd_data[63:32]    <= tx_pcie_byte_count;
       MON_TX_PCIE_PAYLOAD_COUNT    : reg_rd_data[63:32]    <= tx_pcie_payload_count;

       MON_INIT_FC_CPLD             : reg_rd_data[63:32]    <= {24'b0, init_fc_cpld};
       MON_INIT_FC_NPD              : reg_rd_data[63:32]    <= {24'b0, init_fc_npd};
       MON_INIT_FC_PD               : reg_rd_data[63:32]    <= {24'b0, init_fc_pd};

       RAWDATA_PKT_LEN0             : reg_rd_data[63:32]    <= {16'b0, pkt_len0};
       RAWDATA_CHECKER_STATUS0      : reg_rd_data[63:32]    <= {31'b0, data_mismatch0};

       RAWDATA_PKT_LEN1             : reg_rd_data[63:32]    <= {16'b0, pkt_len1};
       RAWDATA_CHECKER_STATUS1      : reg_rd_data[63:32]    <= {31'b0, data_mismatch1};

       END_ADDR_P0                  : reg_rd_data[63:32]    <= end_addr_p0;         
       RD_BURST_SIZE_P0             : reg_rd_data[63:32]    <= {23'b0, rd_burst_size_p0};   
       END_ADDR_P1                  : reg_rd_data[63:32]    <= end_addr_p1;        
       RD_BURST_SIZE_P1             : reg_rd_data[63:32]    <= {23'b0, rd_burst_size_p1};   
       END_ADDR_P2                  : reg_rd_data[63:32]    <= end_addr_p2;        
       RD_BURST_SIZE_P2             : reg_rd_data[63:32]    <= {23'b0, rd_burst_size_p2};  
       END_ADDR_P3                  : reg_rd_data[63:32]    <= end_addr_p3;        
       RD_BURST_SIZE_P3             : reg_rd_data[63:32]    <= {23'b0, rd_burst_size_p3};  

       default                      : reg_rd_data[63:32]     <= 32'b0;
  endcase
end

//+++++++++++++++++++++++++++++++++++++++++++++++++
//  Taken from NWL register_axi_example.v 

// ------------
// Target Reads
// ------------

assign arready = (rd_count == 0);
// read more data if count!=0, output register is ready, no data is on hold
assign rd_en   = (rd_count != 0) & (~rvalid | rready) & ~hold_valid;

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
        rd_count <= 8'h0;
        reg_rd_addr <= {16{1'b0}};
        read_valid  <= 1'b0;
        read_last   <= 1'b0;
        hold_valid  <= 1'b0;
        hold_data   <= {CORE_DATA_WIDTH{1'b0}};
        hold_last   <= 1'b0;
    end
    else begin
        if (arvalid & arready) begin
            reg_rd_addr <= (arregion == 3'h0) ? araddr[15:0] : 0;
            rd_count  <= arlen + 1;
        end
        else if (rd_en) begin
            reg_rd_addr <= reg_rd_addr + {{16{1'b0}}, 1'b1};
            rd_count <= rd_count - 1;
        end

        read_valid <= rd_en;
        read_last  <= (rd_count == 1);

        // read data arrives, output register stalled -> hold the data
        if (read_valid & rvalid & ~rready) begin
            hold_data  <= reg_rd_data;
            hold_last  <= read_last;
            hold_valid <= 1'b1;
        end
        // hold data is moved to output
        else if ((~rvalid | rready) & hold_valid)
            hold_valid <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) begin
        rdata  <= {CORE_DATA_WIDTH{1'b0}};
        rvalid <= 1'b0;
        rlast  <= 1'b0;
        rresp  <= 2'h0;
    end
    else begin
        // read data arrives, output register ready
        if ((~rvalid | rready) & read_valid) begin
            rdata  <= reg_rd_data;
            rvalid <= 1'b1;
            rresp  <= 2'h0;
            rlast  <= read_last;
        end
        // hold data waiting, output register ready
        else if ((~rvalid | rready) & hold_valid) begin
            rdata  <= hold_data;
            rvalid <= 1'b1;
            rresp  <= 2'b0;
            rlast  <= hold_last;
        end
        else if (rready)
            rvalid <= 1'b0;
    end
end


// --------------
// Target Writes
// --------------
assign awready = (wr_count == 0);
assign wready = (wr_count != 0) & (~bvalid | bready);

always @(posedge clk or negedge rst_n) 
begin
    if (rst_n == 1'b0) begin
        wr_addr     <= {16{1'b0}};
        wr_count    <= 8'h0;

        reg_wr_addr <= {16{1'b0}};
        reg_wr_data <= {CORE_DATA_WIDTH{1'b0}};
        reg_wr_en   <= 1'b0;
        reg_wr_be   <= {CORE_BE_WIDTH{1'b0}};

        bvalid      <= 1'b0;
        bresp       <= 2'b0;
    end
    else begin
        if (awvalid & awready) begin
            wr_addr  <= awaddr[15:0];
            wr_count <= awlen + 1;
        end
        else if (wvalid & wready) begin
            wr_count    <= wr_count - 1;
            wr_addr     <= wr_addr + 1;
        end

        if (wvalid & wready) begin
            reg_wr_addr <= (awregion == 3'h0) ? wr_addr : 0;
            reg_wr_data <= wdata;
            reg_wr_en   <= 1'b1;
            reg_wr_be   <= wstrb;
        end
        else begin
            reg_wr_en <= 1'b0;
        end

        if (wvalid & wready & wlast) begin
            bresp  <= 2'h0;
            bvalid <= 1'b1;
        end
        else if (bready)
            bvalid <= 1'b0;
    end
end
//+++++++++++++++++++++++++++++++++++++++++++++++++


endmodule
