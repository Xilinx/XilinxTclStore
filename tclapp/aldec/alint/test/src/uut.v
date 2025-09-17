`timescale 1ns / 1ps
module UUT(CLK,RST,D,O);

input CLK;
input RST;
input  [3:0] D;
output [3:0] O;
reg [3:0] O;

always @(posedge CLK)
	if (RST)
		O <= 'b0;
	else
	    O <= D;
	
endmodule
