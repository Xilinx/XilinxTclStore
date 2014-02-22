module ff_ce_sync_rst (clk,ce,rst,d,q);
                                                           
parameter INIT_VALUE = 1;

input clk,ce,rst;
input d;
output reg q = INIT_VALUE;

always @(posedge clk) begin
	if (rst) begin
		q <= INIT_VALUE;
	end else if (ce) begin
		q <= d;
	end
end
        
endmodule
