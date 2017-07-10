// This design contains one fase path, one multi-cycle path, and one clock domain crossing.
module bp_install_check (clk, a, b, c, d, e, o, ipcdc, clk2, rst_n, opcdc);

input clk, a, b, clk2, rst_n, ipcdc;
input [2:0] c; // False path control: 'c' cannot simultaneously equal 2 and 3
input d, e; 
output o, opcdc;

wire d1, d2, s;
reg m1;
reg m2;
reg m2r;
reg br;
reg ar;
reg t;
reg qcdc1, qcdc2, qcdc3;
reg qmcp1, qmcp2;
reg [1:0] cnt;

assign opcdc = qcdc3;

//design to demo false path detection implementation
always @ (d or m2 or e)
	t = d ? e : m2;

always @ (posedge clk)
begin
	br <= b; // False path start
end
always @ (posedge clk)
begin
	ar <= a;
end
always @ (posedge clk)
begin
	m2r <= t; // False path end
end
always @ (ar or br or c)
begin
	if (c == 2'b10) 
		m1 = br;
	else
		m1 = ar;
end

always @ (m1 or c)
begin
	if (c == 2'b11)
		m2 = m1;
	else
		m2 = 1'b0;
end

assign o = m2r;

//design to demo synchronized clock crossing domain implementation
always @(posedge clk or negedge rst_n)
begin // Output of flip-flop qcdc1 on sending clock 'clk' feeds qcdc2 on 'clk2'
	if (!rst_n)
		qcdc1  <= 1'b0;
	else
		qcdc1  <= ipcdc;
end  // posedge clk end

always @(posedge clk2 or negedge rst_n)
begin // Two consecutive flip-flops on the receiving clock constitute a synchronizer
	if (!rst_n)
		begin
			qcdc2  <= 1'b0;
			qcdc3  <= 1'b0;
		end //
	else
		begin
			qcdc2  <= qcdc1 ;
			qcdc3  <= qcdc2 ;
		end //
end // posedge clk2 end

//design to demo multicycle path implementation
assign d1 = s ? a : qmcp1; // State retention for flip-flop qmcp1
assign d2 = s ? qmcp1 : qmcp2; // State retention for flip-flop qmcp2
assign s = (cnt == 2'b10) ? 1'b1 : 1'b0; // Cyclic signal driving enable for both flip-flops

always @(posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0)
		begin
			qmcp1 <= 1'b0;
			qmcp2 <= 1'b0;
			cnt <= 2'b00;
		end
	else
		begin
			qmcp1 <= d1;
			qmcp2 <= d2;
			cnt <= cnt + 1;
		end
end // posedge clk end

endmodule

