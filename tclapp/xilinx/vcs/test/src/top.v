`timescale 1ns / 1ps
module top(CLK,DIN,DOUT);

input CLK;
input  [2:0] DIN;
output [2:0] DOUT;
reg [2:0] DOUT;

always @(posedge CLK)
      DOUT <= DIN;

endmodule
