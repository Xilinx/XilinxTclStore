//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : out_ddr_flop.v
//  Parent   : Various
//  Children : None
//
//  Description: 
//    This is a wrapper around a basic DDR output flop.
//    A version of this module with identical ports exists for all target
//    technologies for this design (Spartan 3E and Virtex 5).
//    
//
//  Parameters:
//    None
//
//  Notes       : 
//
//  Multicycle and False Paths, Timing Exceptions
//     None
//

`timescale 1ns/1ps


module out_ddr_flop (
  input            clk,          // Destination clock
  input            rst,          // Reset - synchronous to destination clock
  input            d_rise,       // Data for the rising edge of clock
  input            d_fall,       // Data for the falling edge of clock
  output           q             // Double data rate output
);


//***************************************************************************
// Register declarations
//***************************************************************************

//***************************************************************************
// Code
//***************************************************************************

   // ODDR: Output Double Data Rate Output Register with Set, Reset
   //       and Clock Enable.
   //       Virtex-4/5
   // Xilinx HDL Language Template, version 11.1

   ODDRE1 #(
      .IS_C_INVERTED(1'b0),           // Optional inversion for C
      .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
      .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
      .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                      // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
      .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
) ODDRE1_inst (
      .Q   (q),      // 1-bit DDR output
      .C   (clk),    // 1-bit clock input
      //.CE  (1'b1),   // 1-bit clock enable input
      .D1  (d_rise), // 1-bit data input (positive edge)
      .D2  (d_fall), // 1-bit data input (negative edge)
      //.R   (rst),    // 1-bit reset
      //.S   (1'b0)    // 1-bit set
      .SR   (rst)    // 1-bit set
   );

//   ODDR #(
//      .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE" 
//      .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
//      .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC" 
//   ) ODDR_inst (
//      .Q   (q),      // 1-bit DDR output
//      .C   (clk),    // 1-bit clock input
//      .CE  (1'b1),   // 1-bit clock enable input
//      .D1  (d_rise), // 1-bit data input (positive edge)
//      .D2  (d_fall), // 1-bit data input (negative edge)
//      .R   (rst),    // 1-bit reset
//      .S   (1'b0)    // 1-bit set
//   );

   // End of ODDR_inst instantiation

endmodule

