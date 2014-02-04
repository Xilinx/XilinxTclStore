
(* CORE_GENERATION_INFO = "mmcm0,clk_wiz_v4_4,{component_name=mmcm0,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primitive=MMCME2,num_out_clk=3,clkin1_period=10.0,clkin2_period=10.0,use_power_down=false,use_reset=false,use_locked=false,use_inclk_stopped=false,feedback_type=SINGLE,clock_mgr_type=NA,manual_override=false}" *)

module bench16 (reset, clk, sel, in1, in2, in3, in4, in5, in6, in7, in8, in9,
		out1, out2, out3, out4, out5, out6);

/******************************************************************************/
/* Parameter definitions                                                      */
/******************************************************************************/

/******************************************************************************/
/* Input definitions                                                          */
/******************************************************************************/
input reset;
input clk;
input sel;
input in1;
input in2;
input in3;
input in4;
input in5;
input in6;
input in7;
input in8;
input in9;

/******************************************************************************/
/* Output definitions                                                         */
/******************************************************************************/
output out1;
output out2;
output out3;
output out4;
output out5;
output out6;

/******************************************************************************/
/* Register and Wire definitions                                              */
/******************************************************************************/
reg int10;
reg int11;
reg int12;
reg int20;
reg int21;
reg int22;

wire out1 = int20 & in1;
wire out2 = int20 & in5;
wire out3 = int21 | in6;
wire out4 = int21 | in9;
wire out5 = ~int22;
wire out6 = ~int12;
   
wire clk_100i;
wire clk_200i;
wire clk_166i; 

wire clk_i;
   
mmcm0_clk_wiz mmcm_inst (// Clock in ports
			 .CLK_100(clk),
			 // Clock out ports  
			 .CLK_100i(clk_100i),
			 .CLK_200i(clk_200i),
			 .CLK_166i(clk_166i));

mux2 mux2_inst (.din_0(clk_166i), .din_1(clk_200i), .sel(sel), .mux_out(clk_i));
   
always @(posedge reset, negedge clk_100i)
begin
   if (reset)
     begin
	int10 <= 0;
     end
   else
     begin
	int10 <= in2 ^ in3 ^ in4;
     end // end if reset
end // always
   
always @(posedge reset, posedge clk_200i)
begin
   if (reset)
     begin
	int11 <= 0;
     end
   else
     begin
	int11 <= in7 ^ in8;
     end // end if reset
end // always

always @(posedge reset, posedge clk_i)
begin
   if (reset)
     begin
	int12 <= 0;
     end
   else
     begin
	int12 <= in1 ^ in2;
     end // end if reset
end // always

always @(posedge reset, posedge clk_100i)
begin
   if (reset)
     begin
	int20 <= 0;
     end
   else
     begin
	int20 <= int10 ^ in1;
     end // end if reset
end // always

always @(posedge reset, posedge clk_200i)
begin
   if (reset)
     begin
	int21 <= 0;
     end
   else
     begin
	int21 <= int11 ^ in6;
     end // end if reset
end // always

always @(posedge reset, posedge clk_200i)
begin
   if (reset)
     begin
	int22 <= 0;
     end
   else
     begin
	int22 <= int10 ^ in1;
     end // end if reset
end // always
   
/******************************************************************************/
/* Schema                                                                     */
/******************************************************************************/
/*
  _________________________________________ bench16 ________________________________
 |                                                                                  |
                                               reset
                                                 |           
                                              +--o--+        +---+
                                          +---|     |--------|INV|------------<out5>
                                          |   |int22|        |   |
                                          |   |     |        +---+
                                          |   +--^--+
                                          |      |
                                          |      +---> clk_200i
                                          |                    +---+
   <in1>----------------------+--------------------------------|AND|----------<out1>
                              |           |                  +-|   |
                      reset   |           |     reset        | +---+
                        |     |  +---+    |       |          |
            +---+    +--o--+  +--|XOR|    |    +--o--+       |  +---+
   <in2>----|XOR|----|     |-----|   |----+----|     |-------+--|AND|---------<out2>
   <in3>----|   |    |int10|     +---+         |int20|       +--|   |
   <in4>----|   |    |     |                   |     |       |  +---+
            +---+    +--^--+                   +--^--+       |
                        |                         |          |
           clk_100i <---+-------------------------+          |
                                                             |
   <in5>-----------------------------------------------------+
         
   <reset>---------------------------------------------------+
                                                             |
                                                +---+     +--o--+     +---+
               +------+                in1 <----|XOR|-----|     |-----|INV|---<out6>
               |      |clk_100i        in2 <----|   |     |int12|     |   |
               |      |----------->             +---+     |     |     +---+
               |      |                                   +--^--+
               |      |clk_166i                              |
   <clk>-------| MMCM |--------------------+   _             |
               |      |                    |  | \            |
               |      |clk_200i            |  |  \           |
               |      |-----------+        +--|   |          |
               +------+           |           |mux|----------+
                                  +-----------|   |
                                              |  /
                                              |_/|
                                                 |
   <sel>-----------------------------------------+
 
                                                               +---+
   <in6>----------------------+--------------------------------|OR |----------<out3>
                              |                              +-|   |
                      reset   |                 reset        | +---+
                        |     |  +---+            |          |
            +---+    +--o--+  +--|AND|         +--o--+       |  +---+
   <in7>----|XOR|----|     |-----|   |---------|     |-------+--|OR |---------<out4>
   <in8>----|   |    |int11|     +---+         |int21|       +--|   |
            +---+    |     |                   |     |       |  +---+
                     +--^--+                   +--^--+       |
                        |                         |          |
           clk_200i <---+-------------------------+          |
                                                             |
   <in9>-----------------------------------------------------+
 
|___________________________________________________________________________________|

*/

// tested module instanciation
// ***************************
//

endmodule /* end of bench16 */ // unmatched end(function|task|module|primitive|interface|package|class|clocking)

