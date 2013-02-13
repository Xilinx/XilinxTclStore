module top();
 test uut();
endmodule

module test();
 reg clk;
  
 initial begin
   clk = 1'b0;
   forever #5 clk = ~clk;
 end
 initial #20 $finish();
endmodule
