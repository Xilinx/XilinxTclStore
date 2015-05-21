interface SC;

wire clk, rst, in, q;

modport dir();

endinterface


module top(in1, clk1, clk2, rst, q);

input in1, clk1,...;


reg t;

always@(posedge clk1 or posedge rst)
begin
    if(rst)
        t <= 0;
    else
        t <= in1;
end


SC u_sc1(.clk(clk2), .rst(rst), .in(t), .q(q));

sync_cell u_synccell(u_sc1.dir)

endmodule

module sync_cell(SC.dir sc);

reg t;

always@(posedge sc.clk or sc.rst)
begin
    if(sc.rst)
    begin
        t <= 0;
        sc.q <= 0
    end
    else
    begin
        t <= sc.in;
        sc.q <= t;
    end
end

endmodule



