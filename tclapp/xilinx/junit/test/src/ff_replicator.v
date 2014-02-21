module ff_replicator (clk,din,ce,rst,dout);

parameter WIDTH = 10;
parameter STAGES = 10;

input clk;
input [WIDTH-1:0] din;
input ce;
input rst;
output [WIDTH-1:0] dout;

wire [WIDTH-1:0] dint [STAGES:0];

genvar i,j;
generate
	for  (j=0; j < STAGES; j=j+1) begin : ff_stage
		for  (i=0; i < WIDTH; i=i+1) begin : ff_channel
			ff_ce_sync_rst #( .INIT_VALUE(0) ) ff(clk,ce,rst,dint[j][i],dint[j+1][i]);
		end  
	end
endgenerate

assign dint[0] = din;
assign dout = dint[STAGES];

endmodule
