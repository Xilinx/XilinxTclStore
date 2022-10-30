//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : rst_gen.v
//  Parent   : wave_gen.v
//  Children : reset_bridge.v
//
//  Description: 
//     This module is the reset generator for the design.
//     It takes the asynchronous reset in (from the IBUF), and generates
//     three synchronous resets - one on each clock domain.
//
//  Parameters:
//     None
//
//  Notes       : 
//
//  Multicycle and False Paths
//     None

`timescale 1ns/1ps


module rst_gen (
  input             clk_rx,          // Receive clock
  input             clk_tx,          // Transmit clock
  input             clk_samp,        // Sample clock

  input             rst_i,           // Asynchronous input - from IBUF
  input             clock_locked,    // Locked signal from clk_core

  output            rst_clk_rx,      // Reset, synchronized to clk_rx
  output            rst_clk_tx,      // Reset, synchronized to clk_tx
  output            rst_clk_samp     // Reset, synchronized to clk_samp
);

//***************************************************************************
// Function definitions
//***************************************************************************

//***************************************************************************
// Parameter definitions
//***************************************************************************

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire int_rst;
  
//***************************************************************************
// Code
//***************************************************************************

  // Generate the internal reset - it is asserted whenever the reset pin
  // is asserted, or the DCM is not locked
  assign int_rst = rst_i || !clock_locked;

  // Instantiate the reset bridges

  // For clk_rx
  reset_bridge reset_bridge_clk_rx_i0 (
    .clk_dst   (clk_rx),
    .rst_in    (int_rst),
    .rst_dst   (rst_clk_rx)
  );

  // For clk_tx
  reset_bridge reset_bridge_clk_tx_i0 (
    .clk_dst   (clk_tx),
    .rst_in    (int_rst),
    .rst_dst   (rst_clk_tx)
  );
  

  // For clk_samp
  reset_bridge reset_bridge_clk_samp_i0 (
    .clk_dst   (clk_samp),
    .rst_in    (int_rst),
    .rst_dst   (rst_clk_samp)
  );

endmodule
