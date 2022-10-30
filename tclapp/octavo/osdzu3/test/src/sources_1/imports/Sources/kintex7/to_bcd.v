//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2008 Xilinx Inc.
//
//  Project  : wavegen
//  Module   : to_bcd.v
//  Parent   : resp_gen.v
//  Children : None
//
//  Description: 
//     This module takes a 16 bit number and generates the
//     Binary-Coded-Decimal version (5 digits).
//
//     This is intentionally a PAINFULLY inefficient mechanism of doing this
//     conversion, intended to illustrate the need for multi-cycle paths.
//     There are many FAR more efficient ways (both in terms of area and
//     performance) of doing this conversion.
//
//  Parameters:
//     None
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//    This main calculation is structured as a two cycle multi-cycle path
//

`timescale 1ns/1ps


module to_bcd (
  input               clk_rx,       // Input clock, expected to be 50MHz
  input               rst_clk_rx,   // Reset, synchronous to clock
  input               value_val,    // Every 2nd cycle max
  input      [15:0]   value,        // Value to convert
  output reg [18:0]   bcd_out       // BCD output - 5 digits, 4 bits apiece
                                    // except MSdigit, which has 3 bits
);

  reg        old_value_val;
  reg        val_d1;
 
  // These 5 sets of wires are the combinationally derived digits
  reg [2:0]  dig4; // Can only be 0 to 6
  reg [3:0]  dig3, dig2, dig1, dig0;
  
  // These next wires are the remainders from each digit calculation
  reg [13:0] rmn4;     // Must hold 9,999 (14 bits)
  reg [ 9:0] rmn3;     // Must hold 999   (10 bits)
  reg [ 6:0] rmn2;     // Must hold 99    (7 bits)

  // Do 10,000 digit
  // Loop through 7 times - the first will always set the results (since
  // value is >=0 by definition). However, once i*10,000 gets bigger than 
  // the value, it will stop updating dig4 and rmn4, leaving the results set
  // by the last iteration that is true.

  always @(value)
  begin
    if (value >= 16'd60_000) begin
      dig4 = 3'd6; rmn4 = value - 16'd60_000;
    end else if (value >= 16'd50_000) begin
      dig4 = 3'd5; rmn4 = value - 16'd50_000;
    end else if (value >= 16'd40_000) begin
      dig4 = 3'd4; rmn4 = value - 16'd40_000;
    end else if (value >= 16'd30_000) begin
      dig4 = 3'd3; rmn4 = value - 16'd30_000;
    end else if (value >= 16'd20_000) begin
      dig4 = 3'd2; rmn4 = value - 16'd20_000;
    end else if (value >= 16'd10_000) begin
      dig4 = 3'd1; rmn4 = value - 16'd10_000;
    end else begin
      dig4 = 3'd0; rmn4 = value;
    end
  end

  // Now the 1,000 digit
  always @(rmn4)
  begin
    if (rmn4  >= 14'd9_000) begin
      dig3 = 4'd9; rmn3 = rmn4 - 14'd9_000;
    end else if (rmn4  >= 14'd8_000) begin
      dig3 = 4'd8; rmn3 = rmn4 - 14'd8_000;
    end else if (rmn4  >= 14'd7_000) begin
      dig3 = 4'd7; rmn3 = rmn4 - 14'd7_000;
    end else if (rmn4  >= 14'd6_000) begin
      dig3 = 4'd6; rmn3 = rmn4 - 14'd6_000;
    end else if (rmn4  >= 14'd5_000) begin
      dig3 = 4'd5; rmn3 = rmn4 - 14'd5_000;
    end else if (rmn4  >= 14'd4_000) begin
      dig3 = 4'd4; rmn3 = rmn4 - 14'd4_000;
    end else if (rmn4  >= 14'd3_000) begin
      dig3 = 4'd3; rmn3 = rmn4 - 14'd3_000;
    end else if (rmn4  >= 14'd2_000) begin
      dig3 = 4'd2; rmn3 = rmn4 - 14'd2_000;
    end else if (rmn4  >= 14'd1_000) begin
      dig3 = 4'd1; rmn3 = rmn4 - 14'd1_000;
    end else begin
      dig3 = 4'd0; rmn3 = rmn4;
    end
  end

  // Now the 100 digit
  always @(rmn3)
  begin
    if (rmn3  >= 10'd900) begin
      dig2 = 4'd9; rmn2 = rmn3 - 10'd900;
    end else if (rmn3  >= 10'd800) begin
      dig2 = 4'd8; rmn2 = rmn3 - 10'd800;
    end else if (rmn3  >= 10'd700) begin
      dig2 = 4'd7; rmn2 = rmn3 - 10'd700;
    end else if (rmn3  >= 10'd600) begin
      dig2 = 4'd6; rmn2 = rmn3 - 10'd600;
    end else if (rmn3  >= 10'd500) begin
      dig2 = 4'd5; rmn2 = rmn3 - 10'd500;
    end else if (rmn3  >= 10'd400) begin
      dig2 = 4'd4; rmn2 = rmn3 - 10'd400;
    end else if (rmn3  >= 10'd300) begin
      dig2 = 4'd3; rmn2 = rmn3 - 10'd300;
    end else if (rmn3  >= 10'd200) begin
      dig2 = 4'd2; rmn2 = rmn3 - 10'd200;
    end else if (rmn3  >= 10'd100) begin
      dig2 = 4'd1; rmn2 = rmn3 - 10'd100;
    end else begin
      dig2 = 4'd0; rmn2 = rmn3;
    end
  end

  // Now the 10 and 1 digits
  always @(rmn2)
  begin
    if (rmn2  >= 7'd90) begin
      dig1 = 4'd9; dig0 = rmn2 - 7'd90;
    end else if (rmn2  >= 7'd80) begin
      dig1 = 4'd8; dig0 = rmn2 - 7'd80;
    end else if (rmn2  >= 7'd70) begin
      dig1 = 4'd7; dig0 = rmn2 - 7'd70;
    end else if (rmn2  >= 7'd60) begin
      dig1 = 4'd6; dig0 = rmn2 - 7'd60;
    end else if (rmn2  >= 7'd50) begin
      dig1 = 4'd5; dig0 = rmn2 - 7'd50;
    end else if (rmn2  >= 7'd40) begin
      dig1 = 4'd4; dig0 = rmn2 - 7'd40;
    end else if (rmn2  >= 7'd30) begin
      dig1 = 4'd3; dig0 = rmn2 - 7'd30;
    end else if (rmn2  >= 7'd20) begin
      dig1 = 4'd2; dig0 = rmn2 - 7'd20;
    end else if (rmn2  >= 7'd10) begin
      dig1 = 4'd1; dig0 = rmn2 - 7'd10;
    end else begin
      dig1 = 4'd0; dig0 = rmn2;
    end
  end

  // Assert val_d1 only on the clock after value_val is first asserted
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      old_value_val <= 1'b0;
      val_d1        <= 1'b0;
    end // if rst
    else
    begin
      old_value_val <= value_val;
      val_d1        <= value_val && !old_value_val;
    end // if rst
  end

  
  // Only update the output flops when val_d1 is asserted
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      bcd_out <= 19'b0;
    end
    else if (val_d1)
    begin
      bcd_out <= {dig4, dig3, dig2, dig1, dig0};
    end // if val_d1
  end // always

endmodule
