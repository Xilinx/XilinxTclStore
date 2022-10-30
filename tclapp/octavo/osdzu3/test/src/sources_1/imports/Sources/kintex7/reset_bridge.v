//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2008 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : reset_bridge.v
//  Parent   : Various
//  Children : None
//
//  Description: 
//    This is a specialized metastability hardener intended for use in the
//    reset path. The reset will assert ASYNCHRONOUSLY when the input reset is
//    asserted, but will deassert synchronously.
//
//    In designs with asynchronous reset flip-flops, this generates a reset
//    that can meet the "recovery time" requirement of the flip-flop (be sure
//    to enable the recovery time arc checking - ENABLE=reg_sr_r).
//
//    In designs with synchronous resets, it ensures that the reset is
//    available before the first valid clock pulse arrives.
//
//  Parameters:
//    None
//
//  Notes       : 
//
//  Multicycle and False Paths, Timing Exceptions
//    A tighter timing constraint should be placed between the rst_meta
//    and rst_dst flip-flops to allow for meta-stability settling time
//

`timescale 1ns/1ps


module reset_bridge (
  input            clk_dst,      // Destination clock
  input            rst_in,       // Asynchronous reset signal
  output reg       rst_dst       // Synchronized reset signal
);


//***************************************************************************
// Register declarations
//***************************************************************************

  reg           rst_meta;        // After sampling the async rst, this has
                                 // a high probability of being metastable.
                                 // The second sampling (rst_dst) has
                                 // a much lower probability of being
                                 // metastable

//***************************************************************************
// Code
//***************************************************************************

  always @(posedge clk_dst or posedge rst_in)
  begin
    if (rst_in)
    begin
      rst_meta <= 1'b1;
      rst_dst  <= 1'b1;
    end
    else // if !rst_dst
    begin
      rst_meta <= 1'b0;
      rst_dst  <= rst_meta;
    end // if rst
  end // always

endmodule

