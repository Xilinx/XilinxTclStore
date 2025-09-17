`timescale 1ns / 1ps
module testbench;
  
	reg CLK = 0;
	reg RST = 0;
	reg [3:0] D;
	wire [3:0] O;

	UUT uut (
		.CLK(CLK), 
		.RST(RST), 
		.D(D), 
		.O(O)
	);

	initial
		forever	CLK = #10 ~CLK;
	
	initial 
	begin
		RST = 1;
		D = 0;
		#100;
		RST = 0;
		#100;
		D = 3;
		#100;
		D = 4;
		#100;
		D = 7;
		#100;
		D = 0;
		$display("SIMULATION_FINISHED");
	end


  
endmodule
