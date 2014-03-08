`timescale 1ns / 1ps
module tb;
  reg CLK;
  reg [2:0] DIN;
  wire [2:0] DOUT;
  top uut (
    .CLK(CLK), 
    .DIN(DIN), 
    .DOUT(DOUT)
  );
  initial begin
    CLK = 0;
    DIN = 0;
    #100;
  end
endmodule
