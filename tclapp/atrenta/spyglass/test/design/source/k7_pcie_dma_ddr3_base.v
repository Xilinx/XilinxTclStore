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
(* CORE_GENERATION_INFO = "k7_pcie_dma_ddr3_base,k7_pcie_dma_ddr3_base_trd_v1_6,{k7_pcie_dma_ddr3_base=2013.2}" *)
module k7_pcie_dma_ddr3_base #
(
  `ifdef PCIEx8
    parameter NUM_LANES = 8,
  `else 
    parameter NUM_LANES = 4,
  `endif 
    parameter PCIE_EXT_CLK  = "TRUE",
    parameter PL_FAST_TRAIN = "FALSE",
  `ifdef USE_DDR3_FIFO
    parameter CNTWIDTH = 11
  `else
    parameter CNTWIDTH = 13
  `endif  
  )
  (

    input                          perst_n,      // PCI Express slot PERST# reset signal

    input                          pcie_clk_p,   // PCIe 250 MHz differential reference clock input
    input                          pcie_clk_n,   // PCIe 250 MHz differential reference clock input

    output  [NUM_LANES-1:0]        tx_p,         // PCIe differential transmit output
    output  [NUM_LANES-1:0]        tx_n,         // PCIe differential transmit output

    input   [NUM_LANES-1:0]        rx_p,         // PCIe differential receive output
    input   [NUM_LANES-1:0]        rx_n,         // PCIe differential receive output
    input                          emcclk,


`ifdef USE_DDR3_FIFO
    // DDR3 ports
    input                          sys_clk_p,
    input                          sys_clk_n,

    output [13:0]                  ddr_addr,             
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
`endif    
    output  [7:0]                  led           // Diagnostic LEDs

  );



  // ----------------
  // -- Parameters --
  // ----------------
  
  // NUM_LANES indicates the number of PCI Express lanes supported by the core
  localparam  VENDOR_ID               = 16'h10EE; 
  
  localparam  CORE_DATA_WIDTH         = 64;
  localparam  CORE_BE_WIDTH           = CORE_DATA_WIDTH/8;
  localparam  CORE_REMAIN_WIDTH       = 3;
  localparam  DEVICE_SN               = 64'h0;

  localparam  AXIS_TDATA_WIDTH        = CORE_DATA_WIDTH;
  localparam  AXIS_TKEEP_WIDTH        = AXIS_TDATA_WIDTH/8;  

  localparam  REG_ADDR_WIDTH          = 12 + (4 - CORE_REMAIN_WIDTH); 
  
  localparam  LED_CTR_WIDTH           = 26;   // Sets period of LED flashing

`ifdef GEN2_CAP
  localparam USRCLK_FREQ              = 3;
  localparam PIPELINE_STAGES          = 1;
`else
  localparam USRCLK_FREQ              = (NUM_LANES == 4) ? 2 : 3; 
  localparam PIPELINE_STAGES          = (NUM_LANES == 4) ? 0 : 1;
`endif

  // -------------------
  // -- Local Signals --
  // -------------------
  
  // Clock and Reset
  wire                                  sys_clk;
  wire                                  perst_n_c;

  wire    [63:0]                        axi_str_s2c0_tuser;      
  wire                                  axi_str_s2c0_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_s2c0_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_s2c0_tkeep;
  wire                                  axi_str_s2c0_tvalid;          
  wire                                  axi_str_s2c0_tready;          

  wire    [63:0]                        axi_str_c2s0_tuser;      
  wire                                  axi_str_c2s0_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_c2s0_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_c2s0_tkeep;
  wire                                  axi_str_c2s0_tvalid;          
  wire                                  axi_str_c2s0_tready;          

  wire    [63:0]                        axi_str_s2c1_tuser;      
  wire                                  axi_str_s2c1_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_s2c1_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_s2c1_tkeep;
  wire                                  axi_str_s2c1_tvalid;          
  wire                                  axi_str_s2c1_tready;          

  wire    [63:0]                        axi_str_c2s1_tuser;      
  wire                                  axi_str_c2s1_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_c2s1_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_c2s1_tkeep;
  wire                                  axi_str_c2s1_tvalid;          
  wire                                  axi_str_c2s1_tready;          



  reg     [LED_CTR_WIDTH-1:0]           led_ctr;
  reg                                   lane_width_error;
  reg     [LED_CTR_WIDTH-1:0]           led156_ctr;
  reg     [LED_CTR_WIDTH-1:0]           test_clk_ctr;

// -------------------
// -- Local Signals --
// -------------------

// Xilinx Hard Core Instantiation

  wire                                  user_clk;
  wire                                  user_reset;
  wire                                  user_lnk_up;
  wire                                  user_reset_c;
  wire                                  user_lnk_up_c;

  wire   [5:0]                          tx_buf_av;
  wire                                  tx_err_drop;
  wire                                  tx_cfg_req;
  wire                                  s_axis_tx_tready;
  wire   [AXIS_TDATA_WIDTH-1:0]         s_axis_tx_tdata;
  wire   [AXIS_TKEEP_WIDTH-1:0]         s_axis_tx_tkeep;
  wire   [3:0]                          s_axis_tx_tuser;
  wire                                  s_axis_tx_tlast;
  wire                                  s_axis_tx_tvalid;
  wire                                  tx_cfg_gnt;

  wire   [AXIS_TDATA_WIDTH-1:0]         m_axis_rx_tdata;
  wire   [AXIS_TKEEP_WIDTH-1:0]         m_axis_rx_tkeep;
  wire                                  m_axis_rx_tlast;
  wire                                  m_axis_rx_tvalid;
  wire                                  m_axis_rx_tready;
  wire   [21:0]                         m_axis_rx_tuser;
  wire                                  rx_np_ok;
  wire                                  rx_np_req;

  wire    [11:0]                        fc_cpld;
  wire    [7:0]                         fc_cplh;
  wire    [11:0]                        fc_npd;
  wire    [7:0]                         fc_nph;
  wire    [11:0]                        fc_pd;
  wire    [7:0]                         fc_ph;
  wire    [2:0]                         fc_sel;

  wire    [31:0]                        cfg_do;
  wire                                  cfg_rd_wr_done;
  wire    [31:0]                        cfg_di;
  wire    [3:0]                         cfg_byte_en;
  wire    [9:0]                         cfg_dwaddr;
  wire                                  cfg_wr_en;
  wire                                  cfg_rd_en;
  
  wire                                  cfg_err_cor;
  wire                                  cfg_err_ur;
  wire                                  cfg_err_ecrc;
  wire                                  cfg_err_cpl_timeout;
  wire                                  cfg_err_cpl_abort;
  wire                                  cfg_err_cpl_unexpect;
  wire                                  cfg_err_posted;
  wire                                  cfg_err_locked;
  wire    [47:0]                        cfg_err_tlp_cpl_header;
  wire                                  cfg_err_cpl_rdy;

  wire                                  cfg_interrupt;
  wire                                  cfg_interrupt_rdy;
  wire                                  cfg_interrupt_assert;
  wire    [7:0]                         cfg_interrupt_di;
  wire    [7:0]                         cfg_interrupt_do;
  wire    [2:0]                         cfg_interrupt_mmenable;
  wire                                  cfg_interrupt_msienable;
  wire                                  cfg_interrupt_msixenable;
  wire                                  cfg_interrupt_msixfm;

  wire                                  cfg_turnoff_ok;
  wire                                  cfg_to_turnoff;
  wire                                  cfg_trn_pending;
  wire                                  cfg_pm_wake;

  wire    [7:0]                         cfg_bus_number;
  wire    [4:0]                         cfg_device_number;
  wire    [2:0]                         cfg_function_number;
  wire    [15:0]                        cfg_status;
  wire    [15:0]                        cfg_command;
  wire    [15:0]                        cfg_dstatus;
  wire    [15:0]                        cfg_dcommand;
  wire    [15:0]                        cfg_lstatus;
  wire    [15:0]                        cfg_lcommand;
  wire    [15:0]                        cfg_dcommand2;
  wire    [2:0]                         cfg_pcie_link_state;
  wire    [63:0]                        cfg_dsn;

  wire    [2:0]                         pl_initial_link_width;
  wire    [1:0]                         pl_lane_reversal_mode;
  wire                                  pl_link_gen2_capable;
  wire                                  pl_link_partner_gen2_supported;
  wire                                  pl_link_upcfg_capable;
  wire    [5:0]                         pl_ltssm_state;
  wire                                  pl_received_hot_rst;
  wire                                  pl_directed_link_auton;
  wire    [1:0]                         pl_directed_link_change;
  wire                                  pl_directed_link_speed;
  wire    [1:0]                         pl_directed_link_width;
  wire                                  pl_upstream_prefer_deemph;
  wire                                  cfg_err_aer_headerlog_set;
  wire                                  cfg_aer_ecrc_check_en;
  wire                                  cfg_aer_ecrc_gen_en; 
  
  // Wires used for external clocking connectivity
  wire                                  PIPE_PCLK_IN;
  wire                                  PIPE_RXUSRCLK_IN;
  wire  [NUM_LANES-1:0]                 PIPE_RXOUTCLK_IN;
  wire                                  PIPE_DCLK_IN;
  wire                                  PIPE_OOBCLK_IN;     
  wire                                  PIPE_USERCLK1_IN;
  wire                                  PIPE_USERCLK2_IN;
  wire                                  PIPE_MMCM_LOCK_IN;

  wire                                  PIPE_TXOUTCLK_OUT;
  wire [NUM_LANES-1:0]                  PIPE_RXOUTCLK_OUT;
  wire [NUM_LANES-1:0]                  PIPE_PCLK_SEL_OUT;
  wire                                  PIPE_GEN3_OUT;


  wire [7:0]                            clk_period_in_ns;
  
  wire [11:0]                           init_fc_cpld;
  wire [7:0]                            init_fc_cplh;
  wire [11:0]                           init_fc_npd;
  wire [7:0]                            init_fc_nph;
  wire [11:0]                           init_fc_pd;
  wire [7:0]                            init_fc_ph;

  wire [31:0]                           tx_byte_count;
  wire [31:0]                           rx_byte_count;
  wire [31:0]                           tx_payload_count;
  wire [31:0]                           rx_payload_count;


  wire                                  t_awvalid;
  wire                                  t_awready;
  wire    [31:0]                        t_awaddr;
  wire    [3:0]                         t_awlen;
  wire    [2:0]                         t_awregion;
  wire    [2:0]                         t_awsize;

  wire                                  t_wvalid;
  wire                                  t_wready;
  wire    [CORE_DATA_WIDTH-1:0]         t_wdata;
  wire    [CORE_BE_WIDTH-1:0]           t_wstrb;
  wire                                  t_wlast;

  wire                                  t_bvalid;
  wire                                  t_bready;
  wire    [1:0]                         t_bresp;

  wire                                  t_arvalid;
  wire                                  t_arready;
  wire    [31:0]                        t_araddr;
  wire    [3:0]                         t_arlen;
  wire    [2:0]                         t_arregion;
  wire    [2:0]                         t_arsize;

  wire                                  t_rvalid;
  wire    [CORE_DATA_WIDTH-1:0]         t_rdata;
  wire    [1:0]                         t_rresp;
  wire                                  t_rlast;

  wire    [REG_ADDR_WIDTH-1:0]          reg_wr_addr;
  wire                                  reg_wr_en;
  wire    [CORE_BE_WIDTH-1:0]           reg_wr_be;
  wire    [CORE_DATA_WIDTH-1:0]         reg_wr_data;                            
  wire    [REG_ADDR_WIDTH-1:0]          reg_rd_addr;
  wire    [CORE_DATA_WIDTH-1:0]         reg_rd_data;


  wire                                  axi_str_tx_rd0_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_tx_rd0_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_tx_rd0_tkeep;
  wire                                  axi_str_tx_rd0_tvalid;          
  wire                                  axi_str_tx_rd0_tready;          

  wire                                  axi_str_rx_rd0_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_rx_rd0_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_rx_rd0_tkeep;
  wire                                  axi_str_rx_rd0_tvalid;          
  wire                                  axi_str_rx_rd0_tready;          

  wire                                  axi_str_tx_rd1_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_tx_rd1_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_tx_rd1_tkeep;
  wire                                  axi_str_tx_rd1_tvalid;          
  wire                                  axi_str_tx_rd1_tready;          

  wire                                  axi_str_rx_rd1_tlast;              
  wire    [AXIS_TDATA_WIDTH-1:0]        axi_str_rx_rd1_tdata;             
  wire    [AXIS_TKEEP_WIDTH-1:0]        axi_str_rx_rd1_tkeep;
  wire                                  axi_str_rx_rd1_tvalid;          
  wire                                  axi_str_rx_rd1_tready;          

  wire                                  axi_str_c2s0_areset_n;
  wire                                  axi_str_s2c0_areset_n;
  wire                                  axi_str_c2s1_areset_n;
  wire                                  axi_str_s2c1_areset_n;

  wire    [15:0]                        pkt_len0;
  wire    [15:0]                        pkt_len1;
  
  wire    [CNTWIDTH-1:0]                tx_rd0_rd_rdy; 
  wire    [CNTWIDTH-1:0]                c2s0_rd_rdy;   
  wire    [CNTWIDTH-1:0]                tx_rd1_rd_rdy; 
  wire    [CNTWIDTH-1:0]                c2s1_rd_rdy;   

  wire    [CNTWIDTH-1:0]                s2c0_wr_rdy;   
  wire    [CNTWIDTH-1:0]                rx_rd0_wr_rdy; 
  wire    [CNTWIDTH-1:0]                s2c1_wr_rdy;   
  wire    [CNTWIDTH-1:0]                rx_rd1_wr_rdy;

  wire                                  rd0_reset;
  wire                                  rd1_reset;
  
  wire                                  enable_loopback0;
  wire                                  enable_checker0;
  wire                                  enable_generator0;
  wire                                  data_mismatch0;
 
  wire                                  enable_loopback1;
  wire                                  enable_checker1;
  wire                                  enable_generator1;
  wire                                  data_mismatch1;

`ifdef USE_DDR3_FIFO 
  wire                                  calib_done;
  wire    [3:0]                         ddr3_fifo_empty;
  wire                                  axi_ic_mig_shim_rst_n;
  wire    [31:0]                        start_addr_p0;
  wire    [31:0]                        end_addr_p0;
  wire    [8:0]                         wr_burst_size_p0;
  wire    [8:0]                         rd_burst_size_p0;
  wire    [31:0]                        start_addr_p1;
  wire    [31:0]                        end_addr_p1;
  wire    [8:0]                         wr_burst_size_p1;
  wire    [8:0]                         rd_burst_size_p1;
  wire    [31:0]                        start_addr_p2;
  wire    [31:0]                        end_addr_p2;
  wire    [8:0]                         wr_burst_size_p2;
  wire    [8:0]                         rd_burst_size_p2;
  wire    [31:0]                        start_addr_p3;
  wire    [31:0]                        end_addr_p3;
  wire    [8:0]                         wr_burst_size_p3;
  wire    [8:0]                         rd_burst_size_p3;
  wire                                  sda;
  wire                                  scl;
`endif 

// ---------------
// Clock and Reset
// ---------------

// PCIe Reference Clock Input buffer
`ifdef SIMULATION
IBUFDS_GTE2 pcie_clk_ibuf (

    .I      (pcie_clk_p     ),
    .IB     (pcie_clk_n     ),
    .O      (sys_clk        ),
    .CEB    (1'b0           ),
    .ODIV2  (               )

);
`else
IBUFDS_GTE2 pcie_clk_ibuf (

    .I      (pcie_clk_p     ),
    .IB     (pcie_clk_n     ),
    .O      (sys_clk        ),
    .ODIV2  (               )

);
`endif
// PCIe PERST# input buffer
IBUF perst_n_ibuf (

    .I      (perst_n        ),
    .O      (perst_n_c      )

);


// Register to improve timing
FDCP #(

  .INIT     (1'b1           )

) user_lnk_up_int_i (

    .Q      (user_lnk_up    ),
    .D      (user_lnk_up_c  ),
    .C      (user_clk       ),
    .CLR    (1'b0           ),
    .PRE    (1'b0           )

);

// Register to improve timing
FDCP #(

  .INIT(1'b1)

) user_reset_i (

    .Q      (user_reset    ),
    .D      (~user_lnk_up  ),
    .C      (user_clk      ),
    .CLR    (1'b0          ),
    .PRE    (1'b0          )

);

// -------------------------
// PCI Express Core Instance
// -------------------------
  // Generate External Clock Module if External Clocking is selected
  generate
    if (PCIE_EXT_CLK == "TRUE") begin : ext_clk
      localparam USER_CLK_FREQ = USRCLK_FREQ;
      localparam USER_CLK2_DIV2 = "FALSE";
      localparam USERCLK2_FREQ = (USER_CLK2_DIV2 == "TRUE") ? (USER_CLK_FREQ == 4) ? 3 
                                                            : (USER_CLK_FREQ == 3) ? 2 
                                                            :  USER_CLK_FREQ
                                                            :  USER_CLK_FREQ;
      //---------- PIPE Clock Module -------------------------------------------------
      pcie_7x_pipe_clock #(
          .PCIE_ASYNC_EN                  ("FALSE"            ), // PCIe async enable
          .PCIE_TXBUF_EN                  ("FALSE"            ), // PCIe TX buffer enable for Gen1/Gen2 only
          .PCIE_LANE                      (NUM_LANES          ), // PCIe number of lanes
          `ifdef SIMULATION                                      // PCIe Link Speed
            .PCIE_LINK_SPEED              (2                  ),
          `else
            .PCIE_LINK_SPEED              (3                  ),
          `endif
          .PCIE_REFCLK_FREQ               (0                  ), // PCIe reference clock frequency
          .PCIE_USERCLK1_FREQ             (USER_CLK_FREQ +1   ), // PCIe user clock 1 frequency
          .PCIE_USERCLK2_FREQ             (USERCLK2_FREQ +1   ), // PCIe user clock 2 frequency
          .PCIE_DEBUG_MODE                (0                  )
      )
      pipe_clock_i
      (

          //---------- Input -------------------------------------
          .CLK_CLK                        (sys_clk            ),
          .CLK_TXOUTCLK                   (PIPE_TXOUTCLK_OUT  ), // Reference clock from lane 0
          .CLK_RXOUTCLK_IN                (PIPE_RXOUTCLK_OUT  ),
          .CLK_RST_N                      (1'b1               ),
          .CLK_PCLK_SEL                   (PIPE_PCLK_SEL_OUT  ),
          .CLK_GEN3                       (PIPE_GEN3_OUT      ),

          //---------- Output ------------------------------------
          .CLK_PCLK                       (PIPE_PCLK_IN       ),
          .CLK_RXUSRCLK                   (PIPE_RXUSRCLK_IN   ),
          .CLK_RXOUTCLK_OUT               (PIPE_RXOUTCLK_IN   ),
          .CLK_DCLK                       (PIPE_DCLK_IN       ),
          .CLK_OOBCLK                     (PIPE_OOBCLK_IN     ),
          .CLK_USERCLK1                   (PIPE_USERCLK1_IN   ),
          .CLK_USERCLK2                   (PIPE_USERCLK2_IN   ),
          .CLK_MMCM_LOCK                  (PIPE_MMCM_LOCK_IN  )

      );
    end
  endgenerate

pcie_7x pcie_inst (
    //----------------------------------------------------------------------------------------------------------------//
    // 1. PCI Express (pci_exp) Interface                                                                             //
    //----------------------------------------------------------------------------------------------------------------//

    // Tx
    .pci_exp_txp                                (tx_p                           ), // O [7:0]
    .pci_exp_txn                                (tx_n                           ), // O [7:0]

    // Rx
    .pci_exp_rxp                                (rx_p                           ), // I [7:0]
    .pci_exp_rxn                                (rx_n                           ), // I [7:0]

    //----------------------------------------------------------------------------------------------------------------//
    // 2. Clocking Interface - For Partial Reconfig Support                                                           //
    //----------------------------------------------------------------------------------------------------------------//
    .pipe_pclk_in                               (PIPE_PCLK_IN                   ),
    .pipe_rxusrclk_in                           (PIPE_RXUSRCLK_IN               ),
    .pipe_rxoutclk_in                           (PIPE_RXOUTCLK_IN               ),
    .pipe_dclk_in                               (PIPE_DCLK_IN                   ),
    .pipe_userclk1_in                           (PIPE_USERCLK1_IN               ),
    .pipe_oobclk_in                             (PIPE_OOBCLK_IN                 ),
    .pipe_userclk2_in                           (PIPE_USERCLK2_IN               ),
    .pipe_mmcm_lock_in                          (PIPE_MMCM_LOCK_IN              ),
    
    .pipe_txoutclk_out                          (PIPE_TXOUTCLK_OUT              ),
    .pipe_rxoutclk_out                          (PIPE_RXOUTCLK_OUT              ),
    .pipe_pclk_sel_out                          (PIPE_PCLK_SEL_OUT              ),
    .pipe_gen3_out                              (PIPE_GEN3_OUT                  ),

    //----------------------------------------------------------------------------------------------------------------//
    // 3. AXI-S Interface                                                                                             //
    //----------------------------------------------------------------------------------------------------------------//

    // Common
    .user_clk_out                               (user_clk                       ),
    .user_reset_out                             (user_reset_c                   ),
    .user_lnk_up                                (user_lnk_up_c                  ),

    // Tx
    .tx_buf_av                                  (tx_buf_av                      ), // O
    .tx_err_drop                                (tx_err_drop                    ), // O
    .tx_cfg_req                                 (tx_cfg_req                     ), // O
    .s_axis_tx_tready                           (s_axis_tx_tready               ), // O 
    .s_axis_tx_tdata                            (s_axis_tx_tdata                ), // I [CORE_DATA_WIDTH-1:0]
    .s_axis_tx_tkeep                            (s_axis_tx_tkeep                ), // I [CORE_BE_WIDTH-1:0]
    .s_axis_tx_tuser                            (s_axis_tx_tuser                ), // I [3:0]
    .s_axis_tx_tlast                            (s_axis_tx_tlast                ), // I
    .s_axis_tx_tvalid                           (s_axis_tx_tvalid               ), // I

    .tx_cfg_gnt                                 (tx_cfg_gnt                     ), // I

    // Rx
    .m_axis_rx_tdata                            (m_axis_rx_tdata                ), // O  [CORE_DATA_WIDTH-1:0]
    .m_axis_rx_tkeep                            (m_axis_rx_tkeep                ), // O  [CORE_BE_WIDTH-1:0]
    .m_axis_rx_tlast                            (m_axis_rx_tlast                ), // O
    .m_axis_rx_tvalid                           (m_axis_rx_tvalid               ), // O
    .m_axis_rx_tready                           (m_axis_rx_tready               ), // I  
    .m_axis_rx_tuser                            (m_axis_rx_tuser                ), // O  [21:0]
    .rx_np_ok                                   (rx_np_ok                       ), // I
    .rx_np_req                                  (rx_np_req                      ), // I

    // Flow Control
    .fc_cpld                                    (fc_cpld                        ), // O [11:0]
    .fc_cplh                                    (fc_cplh                        ), // O [7:0] 
    .fc_npd                                     (fc_npd                         ), // O [11:0]
    .fc_nph                                     (fc_nph                         ), // O [7:0] 
    .fc_pd                                      (fc_pd                          ), // O [11:0]
    .fc_ph                                      (fc_ph                          ), // O [7:0] 
    .fc_sel                                     (fc_sel                         ), // I [2:0] 

    //----------------------------------------------------------------------------------------------------------------//
    // 4. Configuration (CFG) Interface                                                                               //
    //----------------------------------------------------------------------------------------------------------------//

    //------------------------------------------------//
    // EP and RP                                      //
    //------------------------------------------------//

    .cfg_mgmt_do                                (cfg_do                         ), // O [31:0]
    .cfg_mgmt_rd_wr_done                        (cfg_rd_wr_done                 ), // O

    .cfg_status                                 (cfg_status                     ), // O [15:0]
    .cfg_command                                (cfg_command                    ), // O [15:0]
    .cfg_dstatus                                (cfg_dstatus                    ), // O [15:0]
    .cfg_dcommand                               (cfg_dcommand                   ), // O [15:0]
    .cfg_lstatus                                (cfg_lstatus                    ), // O [15:0]
    .cfg_lcommand                               (cfg_lcommand                   ), // O [15:0]
    .cfg_dcommand2                              (cfg_dcommand2                  ), // O [15:0]
    .cfg_pcie_link_state                        (cfg_pcie_link_state            ), // O [2:0]

    .cfg_pmcsr_pme_en                           (                               ), // O
    .cfg_pmcsr_powerstate                       (                               ), // O [1:0]
    .cfg_pmcsr_pme_status                       (                               ), // O
    .cfg_received_func_lvl_rst                  (                               ), // O

    // Management Interface
    .cfg_mgmt_di                                (cfg_di                         ), // I [31:0]
    .cfg_mgmt_byte_en                           (cfg_byte_en                    ), // I
    .cfg_mgmt_dwaddr                            (cfg_dwaddr                     ), // I [9:0]
    .cfg_mgmt_wr_en                             (cfg_wr_en                      ), // I
    .cfg_mgmt_rd_en                             (cfg_rd_en                      ), // I
    .cfg_mgmt_wr_readonly                       (1'b0                           ), // I

    // Error Reporting Interface
    .cfg_err_ecrc                               (cfg_err_ecrc                   ), // I
    .cfg_err_ur                                 (cfg_err_ur                     ), // I
    .cfg_err_cpl_timeout                        (cfg_err_cpl_timeout            ), // I
    .cfg_err_cpl_unexpect                       (cfg_err_cpl_unexpect           ), // I
    .cfg_err_cpl_abort                          (cfg_err_cpl_abort              ), // I
    .cfg_err_posted                             (cfg_err_posted                 ), // I
    .cfg_err_cor                                (cfg_err_cor                    ), // I
    .cfg_err_atomic_egress_blocked              (1'b0                           ), // I
    .cfg_err_internal_cor                       (1'b0                           ), // I
    .cfg_err_malformed                          (1'b0                           ), // I
    .cfg_err_mc_blocked                         (1'b0                           ), // I
    .cfg_err_poisoned                           (1'b0                           ), // I
    .cfg_err_norecovery                         (1'b0                           ), // I
    .cfg_err_tlp_cpl_header                     (cfg_err_tlp_cpl_header         ), // I [47:0]
    .cfg_err_cpl_rdy                            (cfg_err_cpl_rdy                ), // O
    .cfg_err_locked                             (cfg_err_locked                 ), // I
    .cfg_err_acs                                (1'b0                           ), // I
    .cfg_err_internal_uncor                     (1'b0                           ), // I

    .cfg_trn_pending                            (cfg_trn_pending                ), // I
    .cfg_pm_halt_aspm_l0s                       (1'b0                           ), // I
    .cfg_pm_halt_aspm_l1                        (1'b0                           ), // I
    .cfg_pm_force_state_en                      (1'b0                           ), // I
    .cfg_pm_force_state                         (2'b00                          ), // I

    .cfg_dsn                                    (cfg_dsn                        ), // I [63:0]

    //------------------------------------------------//
    // EP Only                                        //
    //------------------------------------------------//

    .cfg_interrupt                              (cfg_interrupt                  ), // I
    .cfg_interrupt_rdy                          (cfg_interrupt_rdy              ), // O
    .cfg_interrupt_assert                       (cfg_interrupt_assert           ), // I
    .cfg_interrupt_di                           (cfg_interrupt_di               ), // I [7:0]
    .cfg_interrupt_do                           (cfg_interrupt_do               ), // O [7:0]
    .cfg_interrupt_mmenable                     (cfg_interrupt_mmenable         ), // O [2:0]
    .cfg_interrupt_msienable                    (cfg_interrupt_msienable        ), // O 
    .cfg_interrupt_msixenable                   (cfg_interrupt_msixenable       ), // O
    .cfg_interrupt_msixfm                       (cfg_interrupt_msixfm           ), // O
    .cfg_interrupt_stat                         (1'b0                           ),
    .cfg_pciecap_interrupt_msgnum               (5'b00000                       ),

    .cfg_to_turnoff                             (cfg_to_turnoff                 ), // O
    .cfg_turnoff_ok                             (cfg_turnoff_ok                 ), // I
    .cfg_bus_number                             (cfg_bus_number                 ), // O [7:0]
    .cfg_device_number                          (cfg_device_number              ), // O [4:0]
    .cfg_function_number                        (cfg_function_number            ), // O [2:0]
    .cfg_pm_wake                                (cfg_pm_wake                    ), // I

    //------------------------------------------------//
    // RP Only                                        //
    //------------------------------------------------//
    .cfg_pm_send_pme_to                         ( 1'b0 ),
    .cfg_ds_bus_number                          ( 8'b0 ),      // FIXME - Need to fix when RP supported
    .cfg_ds_device_number                       ( 5'b0 ),      // FIXME - Need to fix when RP supported
    .cfg_ds_function_number                     ( 3'b0 ),      // FIXME - Need to fix when RP supported
    .cfg_mgmt_wr_rw1c_as_rw                     ( 1'b0 ),
    .cfg_msg_received                           ( ),           // FIXME - RP Outputs only. Identify if they need to drive anywhere
    .cfg_msg_data                               ( ),

    .cfg_bridge_serr_en                         ( ),           // FIXME - RP Outputs only. Identify if they need to drive anywhere
    .cfg_slot_control_electromech_il_ctl_pulse  ( ),
    .cfg_root_control_syserr_corr_err_en        ( ),
    .cfg_root_control_syserr_non_fatal_err_en   ( ),
    .cfg_root_control_syserr_fatal_err_en       ( ),
    .cfg_root_control_pme_int_en                ( ),
    .cfg_aer_rooterr_corr_err_reporting_en      ( ),
    .cfg_aer_rooterr_non_fatal_err_reporting_en ( ),
    .cfg_aer_rooterr_fatal_err_reporting_en     ( ),
    .cfg_aer_rooterr_corr_err_received          ( ),
    .cfg_aer_rooterr_non_fatal_err_received     ( ),
    .cfg_aer_rooterr_fatal_err_received         ( ),

    .cfg_msg_received_err_cor                   ( ),           // FIXME - RP Outputs only. Identify if they need to drive anywhere
    .cfg_msg_received_err_non_fatal             ( ),
    .cfg_msg_received_err_fatal                 ( ),
    .cfg_msg_received_pm_as_nak                 ( ),
    .cfg_msg_received_pme_to_ack                ( ),
    .cfg_msg_received_assert_int_a               ( ),
    .cfg_msg_received_assert_int_b               ( ),
    .cfg_msg_received_assert_int_c               ( ),
    .cfg_msg_received_assert_int_d               ( ),
    .cfg_msg_received_deassert_int_a             ( ),
    .cfg_msg_received_deassert_int_b             ( ),
    .cfg_msg_received_deassert_int_c             ( ),
    .cfg_msg_received_deassert_int_d             ( ),

`ifndef SIMULATION    
    //drp 
       .pcie_drp_clk(1'b0),
       .pcie_drp_en(1'b0),
       .pcie_drp_we(1'b0),
       .pcie_drp_addr(8'b0),
       .pcie_drp_di(15'b0),
//       .pcie_drp_do(15'b0),
//       .pcie_drp_rdy(1'b0),
`endif 
    //----------------------------------------------------------------------------------------------------------------//
    // 5. Physical Layer Control and Status (PL) Interface                                                            //
    //----------------------------------------------------------------------------------------------------------------//

    .pl_directed_link_change                    (pl_directed_link_change        ), // I [1:0]
    .pl_directed_link_width                     (pl_directed_link_width         ), // I [1:0]
    .pl_directed_link_speed                     (pl_directed_link_speed         ), // I      
    .pl_directed_link_auton                     (pl_directed_link_auton         ), // I      
    .pl_upstream_prefer_deemph                  (pl_upstream_prefer_deemph      ), // I

    .pl_sel_lnk_rate                            (),
    .pl_sel_lnk_width                           (),
    .pl_ltssm_state                             (pl_ltssm_state                 ), // O [5:0] 
    .pl_lane_reversal_mode                      (pl_lane_reversal_mode          ), // O [1:0] 

    .pl_phy_lnk_up                              (),
    .pl_tx_pm_state                             (                               ), // O
    .pl_rx_pm_state                             (                               ), // O

    .pl_link_upcfg_cap                          (pl_link_upcfg_capable          ), // O      
    .pl_link_gen2_cap                           (pl_link_gen2_capable           ), // O      
    .pl_link_partner_gen2_supported             (pl_link_partner_gen2_supported ), // O      
    .pl_initial_link_width                      (pl_initial_link_width          ), // O [2:0] 
    .pl_directed_change_done                    (                               ), // O
    
    //------------------------------------------------//
    // EP Only                                        //
    //------------------------------------------------//
    .pl_received_hot_rst                        (pl_received_hot_rst            ),

    //------------------------------------------------//
    // RP Only                                        //
    //------------------------------------------------//
    .pl_transmit_hot_rst                        (1'b0 ),  // FIXME - Need to look at when RP supported
    .pl_downstream_deemph_source                (1'b0 ),  // FIXME - Need to look at when RP supported

    //-------------------------------------------------------
    // 5. AER Interface
    //-------------------------------------------------------

    .cfg_err_aer_headerlog                      (128'h0                         ),
    .cfg_aer_interrupt_msgnum                   (5'b00000                       ),
    .cfg_err_aer_headerlog_set                  (cfg_err_aer_headerlog_set      ),
    .cfg_aer_ecrc_check_en                      (cfg_aer_ecrc_check_en          ),
    .cfg_aer_ecrc_gen_en                        (cfg_aer_ecrc_gen_en            ),

    //----------------------------------------------------------------------------------------------------------------//
    // 7. VC interface                                                                                                //
    //----------------------------------------------------------------------------------------------------------------//
    .cfg_vc_tcvc_map                            ( ),

    //----------------------------------------------------------------------------------------------------------------//
    // 8. System  (SYS) Interface                                                                                     //
    //----------------------------------------------------------------------------------------------------------------//

    .sys_clk                                    (sys_clk                        ), // I
    .pipe_mmcm_rst_n                            (1'b1                           ),
    .sys_rst_n                                  (perst_n_c                      )  // I

);

//+++++++++++++++++++++++++++++++++++++++++++++++++
//  Taken from NWL xil_pcie_wrapper.v 

// ---------------------------------
// Physical Layer Control and Status

assign pl_directed_link_change      = 2'h0;
assign pl_directed_link_width       = 2'h0;
assign pl_directed_link_speed       = 1'b0;
assign pl_directed_link_auton       = 1'b0;
assign pl_upstream_prefer_deemph    = 1'b1;

// -------------------------------
// Device Serial Number Capability

assign cfg_dsn                      = DEVICE_SN;

//+++++++++++++++++++++++++++++++++++++++++++++++++++

// -------------------------
// Packet DMA Instance
// -------------------------
`ifdef GEN2_CAP
    assign clk_period_in_ns = 'h4; // always use 250 MHz for GEN2
`else
    assign clk_period_in_ns = (NUM_LANES == 4) ? 'h8 : 'h4; // use 125 MHz for x4 GEN1 and 250 MHz for x8 GEN1
`endif
 
assign rx_np_req = 1'b1;

packet_dma_axi # (
    .CORE_BE_WIDTH                   (CORE_BE_WIDTH             ),
    .CORE_DATA_WIDTH                 (CORE_DATA_WIDTH           )
) packet_dma_axi_inst (          
                                    
    .user_reset                      (user_reset                ),
    .user_clk                        (user_clk                  ),
    .user_lnk_up                     (user_lnk_up               ),
    .clk_period_in_ns                (clk_period_in_ns          ),
                                    
    .user_interrupt                  (1'b0                      ), 
                                    
    // Tx                           
    .s_axis_tx_tready                (s_axis_tx_tready          ), // I 
    .s_axis_tx_tdata                 (s_axis_tx_tdata           ), // O [CORE_DATA_WIDTH-1:0]
    .s_axis_tx_tkeep                 (s_axis_tx_tkeep           ), // O [CORE_BE_WIDTH-1:0]
    .s_axis_tx_tuser                 (s_axis_tx_tuser           ), // O [3:0]
    .s_axis_tx_tlast                 (s_axis_tx_tlast           ), // O
    .s_axis_tx_tvalid                (s_axis_tx_tvalid          ), // O
                                    
    .tx_cfg_gnt                      (tx_cfg_gnt                ), // O
    .tx_cfg_req                      (tx_cfg_req                ), // I
    .tx_buf_av                       (tx_buf_av                 ), // I
    .tx_err_drop                     (tx_err_drop               ), // I
                                    
    // Rx                           
    .m_axis_rx_tdata                 (m_axis_rx_tdata           ), // I  [CORE_DATA_WIDTH-1:0]
    .m_axis_rx_tkeep                 (m_axis_rx_tkeep           ), // I  [CORE_BE_WIDTH-1:0]
    .m_axis_rx_tlast                 (m_axis_rx_tlast           ), // I
    .m_axis_rx_tvalid                (m_axis_rx_tvalid          ), // I
    .m_axis_rx_tready                (m_axis_rx_tready          ), // O  
    .m_axis_rx_tuser                 (m_axis_rx_tuser           ), // I  [21:0]
                                    
    .rx_np_ok                        (rx_np_ok                  ), // O
                                    
    // Flow Control                 
    .fc_cpld                         (fc_cpld                   ), // I [11:0]
    .fc_cplh                         (fc_cplh                   ), // I [7:0] 
    .fc_npd                          (fc_npd                    ), // I [11:0]
    .fc_nph                          (fc_nph                    ), // I [7:0] 
    .fc_pd                           (fc_pd                     ), // I [11:0]
    .fc_ph                           (fc_ph                     ), // I [7:0] 
    .fc_sel                          (fc_sel                    ), // I [2:0] 
                                    
    .cfg_mgmt_di                     (cfg_di                    ), // O [31:0]
    .cfg_mgmt_byte_en                (cfg_byte_en               ), // O
    .cfg_mgmt_dwaddr                 (cfg_dwaddr                ), // O [9:0]
    .cfg_mgmt_wr_en                  (cfg_wr_en                 ), // O
    .cfg_mgmt_rd_en                  (cfg_rd_en                 ), // O
                                    
    .cfg_err_cor                     (cfg_err_cor               ), // O
    .cfg_err_ur                      (cfg_err_ur                ), // O
    .cfg_err_ecrc                    (cfg_err_ecrc              ), // O
    .cfg_err_cpl_timeout             (cfg_err_cpl_timeout       ), // O
    .cfg_err_cpl_abort               (cfg_err_cpl_abort         ), // O
    .cfg_err_cpl_unexpect            (cfg_err_cpl_unexpect      ), // O
    .cfg_err_posted                  (cfg_err_posted            ), // O
    .cfg_err_locked                  (cfg_err_locked            ), // O
    .cfg_err_tlp_cpl_header          (cfg_err_tlp_cpl_header    ), // O [47:0]
    .cfg_err_cpl_rdy                 (cfg_err_cpl_rdy           ), // I
                                    
    .cfg_interrupt                   (cfg_interrupt             ), // O
    .cfg_interrupt_rdy               (cfg_interrupt_rdy         ), // I
    .cfg_interrupt_assert            (cfg_interrupt_assert      ), // O
    .cfg_interrupt_di                (cfg_interrupt_di          ), // O [7:0]
    .cfg_interrupt_do                (cfg_interrupt_do          ), // I [7:0]
    .cfg_interrupt_mmenable          (cfg_interrupt_mmenable    ), // I [2:0]
    .cfg_interrupt_msienable         (cfg_interrupt_msienable   ), // I 
    .cfg_interrupt_msixenable        (cfg_interrupt_msixenable  ), // I
    .cfg_interrupt_msixfm            (cfg_interrupt_msixfm      ), // I
                                    
    .cfg_turnoff_ok                  (cfg_turnoff_ok            ), // O
    .cfg_to_turnoff                  (cfg_to_turnoff            ), // I
    .cfg_trn_pending                 (cfg_trn_pending           ), // O
    .cfg_pm_wake                     (cfg_pm_wake               ), // O
                                    
    .cfg_bus_number                  (cfg_bus_number            ), // I [7:0]
    .cfg_device_number               (cfg_device_number         ), // I [4:0]
    .cfg_function_number             (cfg_function_number       ), // I [2:0]
    .cfg_status                      (cfg_status                ), // I [15:0]
    .cfg_command                     (cfg_command               ), // I [15:0]
    .cfg_dstatus                     (cfg_dstatus               ), // I [15:0]
    .cfg_dcommand                    (cfg_dcommand              ), // I [15:0]
    .cfg_lstatus                     (cfg_lstatus               ), // I [15:0]
    .cfg_lcommand                    (cfg_lcommand              ), // I [15:0]
    .cfg_dcommand2                   (cfg_dcommand2             ), // I [15:0]
    .cfg_pcie_link_state             (cfg_pcie_link_state       ), // I [2:0]
                                    
  // DMA BE - C2S Engine #0         
    .c2s0_aclk                       (user_clk                  ),
    .c2s0_tlast                      (axi_str_c2s0_tlast        ),
    .c2s0_tdata                      (axi_str_c2s0_tdata        ),
    .c2s0_tkeep                      (axi_str_c2s0_tkeep        ),
    .c2s0_tvalid                     (axi_str_c2s0_tvalid       ),
    .c2s0_tready                     (axi_str_c2s0_tready       ),
    .c2s0_tuser                      (axi_str_c2s0_tuser        ),
    .c2s0_areset_n                   (axi_str_c2s0_areset_n     ),
                                    
  //DMA BE - C2S Engine #1          
    .c2s1_aclk                       (user_clk                  ),
    .c2s1_tlast                      (axi_str_c2s1_tlast        ),
    .c2s1_tdata                      (axi_str_c2s1_tdata        ),
    .c2s1_tkeep                      (axi_str_c2s1_tkeep        ),
    .c2s1_tvalid                     (axi_str_c2s1_tvalid       ),
    .c2s1_tready                     (axi_str_c2s1_tready       ),
    .c2s1_tuser                      (axi_str_c2s1_tuser        ),
    .c2s1_areset_n                   (axi_str_c2s1_areset_n     ),
                                    
  //DMA BE - S2C Engine #0          
    .s2c0_aclk                       (user_clk                  ),
    .s2c0_tlast                      (axi_str_s2c0_tlast        ),
    .s2c0_tdata                      (axi_str_s2c0_tdata        ),
    .s2c0_tkeep                      (axi_str_s2c0_tkeep        ),
    .s2c0_tvalid                     (axi_str_s2c0_tvalid       ),
    .s2c0_tready                     (axi_str_s2c0_tready       ),
    .s2c0_tuser                      (axi_str_s2c0_tuser        ),
    .s2c0_areset_n                   (axi_str_s2c0_areset_n     ),
                                    
                                    
  //DMA BE - S2C Engine #1                                     
    .s2c1_aclk                       (user_clk                  ),
    .s2c1_tlast                      (axi_str_s2c1_tlast        ),
    .s2c1_tdata                      (axi_str_s2c1_tdata        ),
    .s2c1_tkeep                      (axi_str_s2c1_tkeep        ),
    .s2c1_tvalid                     (axi_str_s2c1_tvalid       ),
    .s2c1_tready                     (axi_str_s2c1_tready       ),
    .s2c1_tuser                      (axi_str_s2c1_tuser        ),
    .s2c1_areset_n                   (axi_str_s2c1_areset_n     ),
                                    
                                    
  //DMA BE - AXI target interface   
    .t_aclk                          (user_clk                  ),
    .t_areset_n                      (~user_reset               ),
    .t_awvalid                       (t_awvalid                 ),   // O
    .t_awready                       (t_awready                 ),   // I 
    .t_awaddr                        (t_awaddr                  ),   // O
    .t_awlen                         (t_awlen                   ),   // O
    .t_awregion                      (t_awregion                ),   // O
    .t_awsize                        (t_awsize                  ),   // O
                                    
    .t_wvalid                        (t_wvalid                  ),   // O
    .t_wready                        (t_wready                  ),   // I
    .t_wdata                         (t_wdata                   ),   // O
    .t_wstrb                         (t_wstrb                   ),   // O
    .t_wlast                         (t_wlast                   ),   // O
                                    
    .t_bvalid                        (t_bvalid                  ),   // I
    .t_bready                        (t_bready                  ),   // O
    .t_bresp                         (t_bresp                   ),   // I
                                    
    .t_arvalid                       (t_arvalid                 ),   // O
    .t_arready                       (t_arready                 ),   // I
    .t_araddr                        (t_araddr                  ),   // O
    .t_arlen                         (t_arlen                   ),   // O
    .t_arregion                      (t_arregion                ),   // O
    .t_arsize                        (t_arsize                  ),   // O
                                    
    .t_rvalid                        (t_rvalid                  ),   // I
    .t_rready                        (t_rready                  ),   // O
    .t_rdata                         (t_rdata                   ),   // I
    .t_rresp                         (t_rresp                   ),   // I
    .t_rlast                         (t_rlast                   )    // I
 
);

`ifdef DMA_LOOPBACK

  assign axi_str_s2c0_tready = axi_str_c2s0_tready;
  assign axi_str_c2s0_tlast = axi_str_s2c0_tlast;
  assign axi_str_c2s0_tvalid = axi_str_s2c0_tvalid;
  assign axi_str_c2s0_tdata = axi_str_s2c0_tdata;
  assign axi_str_c2s0_tkeep = axi_str_s2c0_tkeep;
  assign axi_str_c2s0_tuser = axi_str_s2c0_tuser;
  
  assign axi_str_s2c1_tready = axi_str_c2s1_tready;
  assign axi_str_c2s1_tlast = axi_str_s2c1_tlast;
  assign axi_str_c2s1_tvalid = axi_str_s2c1_tvalid;
  assign axi_str_c2s1_tdata = axi_str_s2c1_tdata;
  assign axi_str_c2s1_tkeep = axi_str_s2c1_tkeep;
  assign axi_str_c2s1_tuser = axi_str_s2c1_tuser;
  
  assign data_mismatch0 = 1'b0;
  assign data_mismatch1 = 1'b0;

`endif


`ifndef DMA_LOOPBACK
  assign axi_str_c2s0_tuser = axi_str_s2c0_tuser;
  assign axi_str_c2s1_tuser = axi_str_s2c1_tuser;
  
  virtual_packet_fifo_wrapper # (
    .AXIS_TDATA_WIDTH (AXIS_TDATA_WIDTH),
    .AXIS_TKEEP_WIDTH (AXIS_TKEEP_WIDTH),
    .CNTWIDTH         (CNTWIDTH)
  ) virtual_pfifo_wrapper_inst (  
`ifdef USE_DDR3_FIFO
    .sys_clk_p                       (sys_clk_p                 ),
    .sys_clk_n                       (sys_clk_n                 ),
    .ddr_addr                        (ddr_addr                  ),
    .ddr_ba                          (ddr_ba                    ),
    .ddr_cas_n                       (ddr_cas_n                 ),
    .ddr_ck_p                        (ddr_ck_p                  ),
    .ddr_ck_n                        (ddr_ck_n                  ),
    .ddr_cke                         (ddr_cke                   ),
    .ddr_cs_n                        (ddr_cs_n                  ),
    .ddr_dm                          (ddr_dm                    ),
    .ddr_dq                          (ddr_dq                    ),
    .ddr_dqs_p                       (ddr_dqs_p                 ),
    .ddr_dqs_n                       (ddr_dqs_n                 ),
    .ddr_odt                         (ddr_odt                   ),
    .ddr_ras_n                       (ddr_ras_n                 ),
    .ddr_reset_n                     (ddr_reset_n               ),
    .ddr_we_n                        (ddr_we_n                  ),
    .sda                             (sda                       ),
    .scl                             (scl                       ),
    .calib_done                      (calib_done                ),
    .ddr3_fifo_empty                 (ddr3_fifo_empty           ),
    .axi_ic_mig_shim_rst_n           (axi_ic_mig_shim_rst_n     ),
    .start_addr_p0                   (start_addr_p0             ),
    .end_addr_p0                     (end_addr_p0               ),
    .wr_burst_size_p0                (wr_burst_size_p0          ),
    .rd_burst_size_p0                (rd_burst_size_p0          ),
    .start_addr_p1                   (start_addr_p1             ),
    .end_addr_p1                     (end_addr_p1               ),
    .wr_burst_size_p1                (wr_burst_size_p1          ),
    .rd_burst_size_p1                (rd_burst_size_p1          ),
    .start_addr_p2                   (start_addr_p2             ),
    .end_addr_p2                     (end_addr_p2               ),
    .wr_burst_size_p2                (wr_burst_size_p2          ),
    .rd_burst_size_p2                (rd_burst_size_p2          ),
    .start_addr_p3                   (start_addr_p3             ),
    .end_addr_p3                     (end_addr_p3               ),
    .wr_burst_size_p3                (wr_burst_size_p3          ),
    .rd_burst_size_p3                (rd_burst_size_p3          ),
`endif     
    .sys_reset                       (!perst_n_c                ),
    .user_reset                      (user_reset                ),
    .user_clk                        (user_clk                  ),
    .axi_str_tx_rd0_tlast            (axi_str_tx_rd0_tlast      ),
    .axi_str_tx_rd0_tdata            (axi_str_tx_rd0_tdata      ),
    .axi_str_tx_rd0_tkeep            (axi_str_tx_rd0_tkeep      ),
    .axi_str_tx_rd0_tvalid           (axi_str_tx_rd0_tvalid     ),
    .axi_str_tx_rd0_tready           (axi_str_tx_rd0_tready     ),
    .axi_str_rx_rd0_tlast            (axi_str_rx_rd0_tlast      ),
    .axi_str_rx_rd0_tdata            (axi_str_rx_rd0_tdata      ),
    .axi_str_rx_rd0_tkeep            (axi_str_rx_rd0_tkeep      ),
    .axi_str_rx_rd0_tvalid           (axi_str_rx_rd0_tvalid     ),
    .axi_str_rx_rd0_tready           (axi_str_rx_rd0_tready     ),
    .axi_str_tx_rd1_tlast            (axi_str_tx_rd1_tlast      ),
    .axi_str_tx_rd1_tdata            (axi_str_tx_rd1_tdata      ),
    .axi_str_tx_rd1_tkeep            (axi_str_tx_rd1_tkeep      ),
    .axi_str_tx_rd1_tvalid           (axi_str_tx_rd1_tvalid     ),
    .axi_str_tx_rd1_tready           (axi_str_tx_rd1_tready     ),
    .axi_str_rx_rd1_tlast            (axi_str_rx_rd1_tlast      ),
    .axi_str_rx_rd1_tdata            (axi_str_rx_rd1_tdata      ),
    .axi_str_rx_rd1_tkeep            (axi_str_rx_rd1_tkeep      ),
    .axi_str_rx_rd1_tvalid           (axi_str_rx_rd1_tvalid     ),
    .axi_str_rx_rd1_tready           (axi_str_rx_rd1_tready     ),
    .axi_str_s2c0_tlast              (axi_str_s2c0_tlast        ),
    .axi_str_s2c0_tdata              (axi_str_s2c0_tdata        ),
    .axi_str_s2c0_tkeep              (axi_str_s2c0_tkeep        ),
    .axi_str_s2c0_tvalid             (axi_str_s2c0_tvalid       ),
    .axi_str_s2c0_tready             (axi_str_s2c0_tready       ),
    .axi_str_c2s0_tlast              (axi_str_c2s0_tlast        ),
    .axi_str_c2s0_tdata              (axi_str_c2s0_tdata        ),
    .axi_str_c2s0_tkeep              (axi_str_c2s0_tkeep        ),
    .axi_str_c2s0_tvalid             (axi_str_c2s0_tvalid       ),
    .axi_str_c2s0_tready             (axi_str_c2s0_tready       ),
    .axi_str_s2c1_tlast              (axi_str_s2c1_tlast        ),
    .axi_str_s2c1_tdata              (axi_str_s2c1_tdata        ),
    .axi_str_s2c1_tkeep              (axi_str_s2c1_tkeep        ),
    .axi_str_s2c1_tvalid             (axi_str_s2c1_tvalid       ),
    .axi_str_s2c1_tready             (axi_str_s2c1_tready       ),
    .axi_str_c2s1_tlast              (axi_str_c2s1_tlast        ),
    .axi_str_c2s1_tdata              (axi_str_c2s1_tdata        ),
    .axi_str_c2s1_tkeep              (axi_str_c2s1_tkeep        ),
    .axi_str_c2s1_tvalid             (axi_str_c2s1_tvalid       ),
    .axi_str_c2s1_tready             (axi_str_c2s1_tready       ),

    .axi_str_c2s0_areset_n           (axi_str_c2s0_areset_n     ),
    .axi_str_s2c0_areset_n           (axi_str_s2c0_areset_n     ),
    .axi_str_c2s1_areset_n           (axi_str_c2s1_areset_n     ),
    .axi_str_s2c1_areset_n           (axi_str_s2c1_areset_n     ),

    .tx_rd0_rd_rdy                   (tx_rd0_rd_rdy             ),
    .c2s0_rd_rdy                     (c2s0_rd_rdy               ),
    .tx_rd1_rd_rdy                   (tx_rd1_rd_rdy             ),
    .c2s1_rd_rdy                     (c2s1_rd_rdy               ),
    
    .s2c0_wr_rdy                     (s2c0_wr_rdy               ),
    .rx_rd0_wr_rdy                   (rx_rd0_wr_rdy             ),
    .s2c1_wr_rdy                     (s2c1_wr_rdy               ),
    .rx_rd1_wr_rdy                   (rx_rd1_wr_rdy             ),

    .pkt_len0                        (pkt_len0                  ),
    .pkt_len1                        (pkt_len1                  )

 );
`endif

`ifndef DMA_LOOPBACK

assign rd0_reset = user_reset | (~axi_str_s2c0_areset_n) | (~axi_str_c2s0_areset_n);

  raw_data_packet #(
    .AXIS_TDATA_WIDTH (AXIS_TDATA_WIDTH),
    .ADD_CHIPSCOPE    (1),
    .CNTWIDTH         (CNTWIDTH)
  ) raw_data_packet_inst0 (
    .reset                          (rd0_reset                  ),
    .clk                            (user_clk                   ),
    .enable_checker                 (enable_checker0            ),
    .enable_generator               (enable_generator0          ),
    .enable_loopback                (enable_loopback0           ),
    .pkt_len                        (pkt_len0                   ),
    .data_mismatch                  (data_mismatch0             ),
    .axi_str_tx_tdata               (axi_str_tx_rd0_tdata       ),
    .axi_str_tx_tkeep               (axi_str_tx_rd0_tkeep       ),
    .axi_str_tx_tvalid              (axi_str_tx_rd0_tvalid      ),
    .axi_str_tx_tlast               (axi_str_tx_rd0_tlast       ),
    .axi_str_tx_tuser               ({16'b0, pkt_len0}          ),
    .axi_str_tx_tready              (axi_str_tx_rd0_tready      ),
    .axi_str_rx_tdata               (axi_str_rx_rd0_tdata       ),
    .axi_str_rx_tkeep               (axi_str_rx_rd0_tkeep       ),
    .axi_str_rx_tvalid              (axi_str_rx_rd0_tvalid      ),
    .axi_str_rx_tlast               (axi_str_rx_rd0_tlast       ),
    .axi_str_rx_tuser               (                           ),
    .axi_str_rx_tready              (axi_str_rx_rd0_tready      ),
    .rd_rdy                         (tx_rd0_rd_rdy              ),
    .wr_rdy                         (rx_rd0_wr_rdy              )
  );

assign rd1_reset = user_reset | (~axi_str_s2c1_areset_n) | (~axi_str_c2s1_areset_n);

  raw_data_packet #(
    .AXIS_TDATA_WIDTH (AXIS_TDATA_WIDTH),
    .CNTWIDTH         (CNTWIDTH)
  ) raw_data_packet_inst1 (
    .reset                          (rd1_reset                  ),
    .clk                            (user_clk                   ),
    .enable_checker                 (enable_checker1            ),
    .enable_generator               (enable_generator1          ),
    .enable_loopback                (enable_loopback1           ),
    .pkt_len                        (pkt_len1                   ),
    .data_mismatch                  (data_mismatch1             ),
    .axi_str_tx_tdata               (axi_str_tx_rd1_tdata       ),
    .axi_str_tx_tkeep               (axi_str_tx_rd1_tkeep       ),
    .axi_str_tx_tvalid              (axi_str_tx_rd1_tvalid      ),
    .axi_str_tx_tlast               (axi_str_tx_rd1_tlast       ),
    .axi_str_tx_tuser               ({16'b0, pkt_len1}          ),
    .axi_str_tx_tready              (axi_str_tx_rd1_tready      ),
    .axi_str_rx_tdata               (axi_str_rx_rd1_tdata       ),
    .axi_str_rx_tkeep               (axi_str_rx_rd1_tkeep       ),
    .axi_str_rx_tvalid              (axi_str_rx_rd1_tvalid      ),
    .axi_str_rx_tlast               (axi_str_rx_rd1_tlast       ),
    .axi_str_rx_tuser               (                           ),
    .axi_str_rx_tready              (axi_str_rx_rd1_tready      ),
    .rd_rdy                         (tx_rd1_rd_rdy              ),
    .wr_rdy                         (rx_rd1_wr_rdy              )
  );
`endif

  


// Monitor to track performance on the 
// transaction interface of the PCIe block
 pcie_performance_monitor pcie_perf_mon_inst
 (
   .clk                             (user_clk                   ),
   .reset                           (!user_lnk_up               ),
   .clk_period_in_ns                (clk_period_in_ns           ),

   // PCIe-AXI Tx
   .s_axis_tx_tdata                 (s_axis_tx_tdata            ),
   .s_axis_tx_tlast                 (s_axis_tx_tlast            ),
   .s_axis_tx_tvalid                (s_axis_tx_tvalid           ),
   .s_axis_tx_tready                (s_axis_tx_tready           ),
   .s_axis_tx_tuser                 (s_axis_tx_tuser            ),

   // PCIe-AXI Rx                              
   .m_axis_rx_tdata                 (m_axis_rx_tdata            ),
   .m_axis_rx_tlast                 (m_axis_rx_tlast            ),
   .m_axis_rx_tvalid                (m_axis_rx_tvalid           ),
   .m_axis_rx_tready                (m_axis_rx_tready           ),

   .fc_cpld                         (fc_cpld                    ),
   .fc_cplh                         (fc_cplh                    ),
   .fc_npd                          (fc_npd                     ),
   .fc_nph                          (fc_nph                     ),
   .fc_pd                           (fc_pd                      ),
   .fc_ph                           (fc_ph                      ),
   .fc_sel                          (fc_sel                     ),

   .init_fc_cpld                    (init_fc_cpld               ),
   .init_fc_cplh                    (init_fc_cplh               ),
   .init_fc_npd                     (init_fc_npd                ),
   .init_fc_nph                     (init_fc_nph                ),
   .init_fc_pd                      (init_fc_pd                 ),
   .init_fc_ph                      (init_fc_ph                 ),

   .tx_byte_count                   (tx_byte_count              ),
   .rx_byte_count                   (rx_byte_count              ),
   .tx_payload_count                (tx_payload_count           ),
   .rx_payload_count                (rx_payload_count           )
 ); 

register_map # (
    .REG_ADDR_WIDTH                 (REG_ADDR_WIDTH             ),
    .CORE_DATA_WIDTH                (CORE_DATA_WIDTH            ),
    .CORE_BE_WIDTH                  (CORE_BE_WIDTH              )
) register_map_inst (

    .rst_n                          (user_lnk_up                ),
    .clk                            (user_clk                   ),

    .awaddr                         (t_awaddr                   ),
    .awvalid                        (t_awvalid                  ),
    .awready                        (t_awready                  ),
    .awlen                          (t_awlen                    ),
    .awregion                       (t_awregion                 ),
    .awsize                         (t_awsize                   ),

    .wdata                          (t_wdata                    ),
    .wvalid                         (t_wvalid                   ),
    .wready                         (t_wready                   ),
    .wlast                          (t_wlast                    ),
    .wstrb                          (t_wstrb                    ),

    .bvalid                         (t_bvalid                   ),
    .bready                         (t_bready                   ),
    .bresp                          (t_bresp                    ),

    .araddr                         (t_araddr                   ),
    .arvalid                        (t_arvalid                  ),
    .arready                        (t_arready                  ),
    .arlen                          (t_arlen                    ),
    .arregion                       (t_arregion                 ),
    .arsize                         (t_arsize                   ),

    .rdata                          (t_rdata                    ),
    .rvalid                         (t_rvalid                   ),
    .rready                         (t_rready                   ),
    .rlast                          (t_rlast                    ),
    .rresp                          (t_rresp                    ),

    // Raw Data Registers
    .enable_checker0                (enable_checker0            ),
    .enable_generator0              (enable_generator0          ),
    .enable_loopback0               (enable_loopback0           ),
    .pkt_len0                       (pkt_len0                   ),
    .data_mismatch0                 (data_mismatch0             ),

    // Raw Data Registers
    .enable_checker1                (enable_checker1            ),
    .enable_generator1              (enable_generator1          ),
    .enable_loopback1               (enable_loopback1           ),
    .pkt_len1                       (pkt_len1                   ),
    .data_mismatch1                 (data_mismatch1             ),

    // Virtual FIFO Controller registers                        ),
    .calib_done                     (calib_done                 ),
    .ddr3_fifo_empty                (ddr3_fifo_empty            ),
    .axi_ic_mig_shim_rst_n          (axi_ic_mig_shim_rst_n      ),
    .start_addr_p0                  (start_addr_p0              ),
    .end_addr_p0                    (end_addr_p0                ),
    .wr_burst_size_p0               (wr_burst_size_p0           ),
    .rd_burst_size_p0               (rd_burst_size_p0           ),
    .start_addr_p1                  (start_addr_p1              ),
    .end_addr_p1                    (end_addr_p1                ),
    .wr_burst_size_p1               (wr_burst_size_p1           ),
    .rd_burst_size_p1               (rd_burst_size_p1           ),
    .start_addr_p2                  (start_addr_p2              ),
    .end_addr_p2                    (end_addr_p2                ),
    .wr_burst_size_p2               (wr_burst_size_p2           ),
    .rd_burst_size_p2               (rd_burst_size_p2           ),
    .start_addr_p3                  (start_addr_p3              ),
    .end_addr_p3                    (end_addr_p3                ),
    .wr_burst_size_p3               (wr_burst_size_p3           ),
    .rd_burst_size_p3               (rd_burst_size_p3           ),

    // Intial Flow Control Credits of the host system 
    .init_fc_cpld                   (init_fc_cpld               ),
    .init_fc_cplh                   (init_fc_cplh               ),
    .init_fc_npd                    (init_fc_npd                ),
    .init_fc_nph                    (init_fc_nph                ),
    .init_fc_pd                     (init_fc_pd                 ),
    .init_fc_ph                     (init_fc_ph                 ),

    // Performance Monitor registers
    .tx_pcie_byte_count             (tx_byte_count              ),
    .rx_pcie_byte_count             (rx_byte_count              ),
    .tx_pcie_payload_count          (tx_payload_count           ),
    .rx_pcie_payload_count          (rx_payload_count           )    
 ); 

// ---------------
// LEDs - Status
// ---------------
// Heart beat LED; flashes when primary PCIe core clock is present
always @(posedge user_clk)
begin
    led_ctr <= led_ctr + {{(LED_CTR_WIDTH-1){1'b0}}, 1'b1};
end

`ifdef SIMULATION
// Initialize for simulation
initial
begin
    led_ctr = {LED_CTR_WIDTH{1'b0}};
end
`endif

always @(posedge user_clk or posedge user_reset)
begin
    if (user_reset == 1'b1)
        lane_width_error <= 1'b0;
    else
        lane_width_error <= (cfg_lstatus[9:4] != NUM_LANES); // Negotiated Link Width
end

// led[0] lights up when PCIe core has trained
assign led[0] = user_lnk_up; 

// led[1] flashes to indicate PCIe clock is running
assign led[1] = led_ctr[LED_CTR_WIDTH-1];            // Flashes when core_clk_i_div2 is present

// led[2] lights up when the correct lane width is acheived
// If the link is not operating at full width, it flashes at twice the speed of the heartbeat on led[1]
assign led[2] = lane_width_error ? led_ctr[LED_CTR_WIDTH-2] : 1'b1;

// When glowing, the DDR3 initialization has completed
`ifdef USE_DDR3_FIFO
assign led[3] = calib_done;
`else
assign led[3] = 1'b0;
`endif

assign led[4] = 1'b0;
assign led[5] = 1'b0;
assign led[6] = 1'b0;
assign led[7] = 1'b0;



endmodule
