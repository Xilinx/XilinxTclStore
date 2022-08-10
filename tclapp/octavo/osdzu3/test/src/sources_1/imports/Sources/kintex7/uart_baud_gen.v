//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2008 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : uart_baud_gen.v
//  Parent   : uart_rx and uart_tx
//  Children : None
//
//  Description: 
//     Generates a 16x Baud enable. This signal is generated 16 times per bit
//     at the correct baud rate as determined by the parameters for the system
//     clock frequency and the Baud rate
//
//  Parameters:
//     BAUD_RATE : Baud rate - set to 57,600bps by default
//     CLOCK_RATE: Clock rate - set to 50MHz by default
//
//  Local Parameters:
//     OVERSAMPLE_RATE: The oversampling rate - 16 x BAUD_RATE
//     DIVIDER    : The number of clocks per baud_x16_en
//     CNT_WIDTH  : Width of the counter
//
//  Notes       : 
//    1) Divider must be at least 2 (thus CLOCK_RATE must be at least 32x
//       BAUD_RATE)
//
//  Multicycle and False Paths
//    None
//

`timescale 1ns/1ps


module uart_baud_gen (
  // Write side inputs
  input        clk,          // Clock input
  input        rst,          // Active HIGH reset - synchronous to clk
  output       baud_x16_en   // Oversampled Baud rate enable
);


//***************************************************************************
// Constant Functions
//***************************************************************************
  // Generate the ceiling of the log base 2 - i.e. the number of bits
  // required to hold N values. A vector of size clogb2(N) will hold the
  // values 0 to N-1
  function integer clogb2;
    input [31:0] value;
    reg   [31:0] my_value;
    begin
      my_value = value - 1;
      for (clogb2 = 0; my_value > 0; clogb2 = clogb2 + 1)
        my_value = my_value >> 1;
    end
  endfunction
  //
//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter BAUD_RATE    = 57_600;              // Baud rate
  parameter CLOCK_RATE   = 50_000_000;

  // The OVERSAMPLE_RATE is the BAUD_RATE times 16
  localparam OVERSAMPLE_RATE = BAUD_RATE * 16;

  // The divider is the CLOCK_RATE / OVERSAMPLE_RATE - rounded up
  // (so add 1/2 of the OVERSAMPLE_RATE before the integer division)
  localparam DIVIDER = (CLOCK_RATE+OVERSAMPLE_RATE/2) / OVERSAMPLE_RATE;

  // The value to reload the counter is DIVIDER-1;
  localparam OVERSAMPLE_VALUE = DIVIDER - 1;

  // The required width of the counter is the ceiling of the base 2 logarithm
  // of the DIVIDER
  localparam CNT_WID = clogb2(DIVIDER);


//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [CNT_WID-1:0] internal_count;
  reg               baud_x16_en_reg;


//***************************************************************************
// Wire declarations
//***************************************************************************
  
  wire [CNT_WID-1:0] internal_count_m_1; // Count minus 1


//***************************************************************************
// Code
//***************************************************************************

  assign internal_count_m_1 = internal_count - 1'b1;

  // Count from DIVIDER-1 to 0, setting baud_x16_en_reg when internal_count=0.
  // The signal baud_x16_en_reg must come from a flop (since it is a module
  // output) so schedule it to be set when the next count is 1 (i.e. when
  // internal_count_m_1 is 0).
  always @(posedge clk)
  begin
    if (rst)
    begin
      internal_count  <= OVERSAMPLE_VALUE;
      baud_x16_en_reg <= 1'b0;
    end
    else
    begin
      // Assert baud_x16_en_reg in the next clock when internal_count will be
      // zero in that clock (thus when internal_count_m_1 is 0).
      baud_x16_en_reg   <= (internal_count_m_1 == {CNT_WID{1'b0}});

      // Count from OVERSAMPLE_VALUE down to 0 repeatedly
      if (internal_count == {CNT_WID{1'b0}}) 
      begin
        internal_count    <= OVERSAMPLE_VALUE;
      end
      else // internal_count is not 0
      begin
        internal_count    <= internal_count_m_1;
      end
    end // if rst
  end // always 

  assign baud_x16_en = baud_x16_en_reg;

endmodule
