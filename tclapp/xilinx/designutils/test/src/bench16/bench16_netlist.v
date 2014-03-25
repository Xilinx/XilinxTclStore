// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.1.0 (lin64) Build 823529 Sun Feb  2 21:01:51 MST 2014
// Date        : Tue Feb  4 13:19:12 2014
// Host        : xsjrdevl22 running 64-bit Red Hat Enterprise Linux Client release 5.6 (Tikanga)
// Command     : write_verilog -mode design bench16_netlist.v
// Design      : bench16
// Purpose     : This is a Verilog netlist of the current design or from a specific cell of the design. The output is an
//               IEEE 1364-2001 compliant Verilog HDL file that contains netlist information obtained from the input
//               design files.
// Device      : xc7k70tfbg484-3
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* core_generation_info = "mmcm0,clk_wiz_v4_4,{component_name=mmcm0,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primitive=MMCME2,num_out_clk=3,clkin1_period=10.0,clkin2_period=10.0,use_power_down=false,use_reset=false,use_locked=false,use_inclk_stopped=false,feedback_type=SINGLE,clock_mgr_type=NA,manual_override=false}" *) 
(* STRUCTURAL_NETLIST = "yes" *)
module bench16
   (reset,
    clk,
    sel,
    in1,
    in2,
    in3,
    in4,
    in5,
    in6,
    in7,
    in8,
    in9,
    out1,
    out2,
    out3,
    out4,
    out5,
    out6);
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
  output out1;
  output out2;
  output out3;
  output out4;
  output out5;
  output out6;

  wire \<const1> ;
(* IBUF_LOW_PWR *)   wire clk;
  wire clk_100i;
  wire clk_166i;
  wire clk_200i;
  wire clk_i;
  wire in1;
  wire in1_IBUF;
  wire in2;
  wire in2_IBUF;
  wire in3;
  wire in3_IBUF;
  wire in4;
  wire in4_IBUF;
  wire in5;
  wire in5_IBUF;
  wire in6;
  wire in6_IBUF;
  wire in7;
  wire in7_IBUF;
  wire in8;
  wire in8_IBUF;
  wire in9;
  wire in9_IBUF;
  wire int10;
  wire int100;
  wire int11;
  wire int110;
  wire int12;
  wire int120;
  wire int20;
  wire int200;
  wire int21;
  wire int210;
  wire int22;
  wire n_0_out1_OBUF_inst_i_1;
  wire n_0_out2_OBUF_inst_i_1;
  wire n_0_out3_OBUF_inst_i_1;
  wire n_0_out4_OBUF_inst_i_1;
  wire n_0_out5_OBUF_inst_i_1;
  wire n_0_out6_OBUF_inst_i_1;
  wire out1;
  wire out2;
  wire out3;
  wire out4;
  wire out5;
  wire out6;
  wire reset;
  wire reset_IBUF;
  wire sel;
  wire sel_IBUF;

VCC VCC
       (.P(\<const1> ));
IBUF in1_IBUF_inst
       (.I(in1),
        .O(in1_IBUF));
IBUF in2_IBUF_inst
       (.I(in2),
        .O(in2_IBUF));
IBUF in3_IBUF_inst
       (.I(in3),
        .O(in3_IBUF));
IBUF in4_IBUF_inst
       (.I(in4),
        .O(in4_IBUF));
IBUF in5_IBUF_inst
       (.I(in5),
        .O(in5_IBUF));
IBUF in6_IBUF_inst
       (.I(in6),
        .O(in6_IBUF));
IBUF in7_IBUF_inst
       (.I(in7),
        .O(in7_IBUF));
IBUF in8_IBUF_inst
       (.I(in8),
        .O(in8_IBUF));
IBUF in9_IBUF_inst
       (.I(in9),
        .O(in9_IBUF));
LUT3 #(
    .INIT(8'h96)) 
     int10_i_1
       (.I0(in4_IBUF),
        .I1(in2_IBUF),
        .I2(in3_IBUF),
        .O(int100));
FDCE #(
    .IS_C_INVERTED(1'b1)) 
     int10_reg
       (.C(clk_100i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int100),
        .Q(int10));
LUT2 #(
    .INIT(4'h6)) 
     int11_i_1
       (.I0(in7_IBUF),
        .I1(in8_IBUF),
        .O(int110));
FDCE int11_reg
       (.C(clk_200i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int110),
        .Q(int11));
(* SOFT_HLUTNM = "soft_lutpair1" *) 
   LUT2 #(
    .INIT(4'h6)) 
     int12_i_1
       (.I0(in1_IBUF),
        .I1(in2_IBUF),
        .O(int120));
FDCE int12_reg
       (.C(clk_i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int120),
        .Q(int12));
(* SOFT_HLUTNM = "soft_lutpair1" *) 
   LUT2 #(
    .INIT(4'h6)) 
     int20_i_1
       (.I0(int10),
        .I1(in1_IBUF),
        .O(int200));
FDCE int20_reg
       (.C(clk_100i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int200),
        .Q(int20));
(* SOFT_HLUTNM = "soft_lutpair2" *) 
   LUT2 #(
    .INIT(4'h6)) 
     int21_i_1
       (.I0(int11),
        .I1(in6_IBUF),
        .O(int210));
FDCE int21_reg
       (.C(clk_200i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int210),
        .Q(int21));
FDCE int22_reg
       (.C(clk_200i),
        .CE(\<const1> ),
        .CLR(reset_IBUF),
        .D(int200),
        .Q(int22));
mmcm0_clk_wiz mmcm_inst
       (.CLK_100i(clk_100i),
        .CLK_166i(clk_166i),
        .CLK_200i(clk_200i),
        .clk(clk));
mux2 mux2_inst
       (.din_0(clk_166i),
        .din_1(clk_200i),
        .mux_out(clk_i),
        .sel(sel_IBUF));
OBUF out1_OBUF_inst
       (.I(n_0_out1_OBUF_inst_i_1),
        .O(out1));
(* SOFT_HLUTNM = "soft_lutpair0" *) 
   LUT2 #(
    .INIT(4'h8)) 
     out1_OBUF_inst_i_1
       (.I0(in1_IBUF),
        .I1(int20),
        .O(n_0_out1_OBUF_inst_i_1));
OBUF out2_OBUF_inst
       (.I(n_0_out2_OBUF_inst_i_1),
        .O(out2));
(* SOFT_HLUTNM = "soft_lutpair0" *) 
   LUT2 #(
    .INIT(4'h8)) 
     out2_OBUF_inst_i_1
       (.I0(in5_IBUF),
        .I1(int20),
        .O(n_0_out2_OBUF_inst_i_1));
OBUF out3_OBUF_inst
       (.I(n_0_out3_OBUF_inst_i_1),
        .O(out3));
(* SOFT_HLUTNM = "soft_lutpair2" *) 
   LUT2 #(
    .INIT(4'hE)) 
     out3_OBUF_inst_i_1
       (.I0(in6_IBUF),
        .I1(int21),
        .O(n_0_out3_OBUF_inst_i_1));
OBUF out4_OBUF_inst
       (.I(n_0_out4_OBUF_inst_i_1),
        .O(out4));
LUT2 #(
    .INIT(4'hE)) 
     out4_OBUF_inst_i_1
       (.I0(in9_IBUF),
        .I1(int21),
        .O(n_0_out4_OBUF_inst_i_1));
OBUF out5_OBUF_inst
       (.I(n_0_out5_OBUF_inst_i_1),
        .O(out5));
LUT1 #(
    .INIT(2'h1)) 
     out5_OBUF_inst_i_1
       (.I0(int22),
        .O(n_0_out5_OBUF_inst_i_1));
OBUF out6_OBUF_inst
       (.I(n_0_out6_OBUF_inst_i_1),
        .O(out6));
LUT1 #(
    .INIT(2'h1)) 
     out6_OBUF_inst_i_1
       (.I0(int12),
        .O(n_0_out6_OBUF_inst_i_1));
IBUF reset_IBUF_inst
       (.I(reset),
        .O(reset_IBUF));
IBUF sel_IBUF_inst
       (.I(sel),
        .O(sel_IBUF));
endmodule

module mmcm0_clk_wiz
   (CLK_100i,
    CLK_200i,
    CLK_166i,
    clk);
  output CLK_100i;
  output CLK_200i;
  output CLK_166i;
  input clk;

  wire \<const0> ;
  wire \<const1> ;
  wire CLK_100_mmcm0;
  wire CLK_100i;
  wire CLK_100i_mmcm0;
  wire CLK_166i;
  wire CLK_166i_mmcm0;
  wire CLK_200i;
  wire CLK_200i_mmcm0;
(* IBUF_LOW_PWR *)   wire clk;
  wire clkfbout_buf_mmcm0;
  wire clkfbout_mmcm0;

GND GND
       (.G(\<const0> ));
VCC VCC
       (.P(\<const1> ));
(* BOX_TYPE = "PRIMITIVE" *) 
   BUFG clkf_buf
       (.I(clkfbout_mmcm0),
        .O(clkfbout_buf_mmcm0));
(* BOX_TYPE = "PRIMITIVE" *) 
   (* CAPACITANCE = "DONT_CARE" *) 
   (* IBUF_DELAY_VALUE = "0" *) 
   (* XILINX_LEGACY_PRIM = "IBUFG" *) 
   IBUF #(
    .IOSTANDARD("DEFAULT")) 
     clkin1_ibufg
       (.I(clk),
        .O(CLK_100_mmcm0));
(* BOX_TYPE = "PRIMITIVE" *) 
   BUFG clkout1_buf
       (.I(CLK_100i_mmcm0),
        .O(CLK_100i));
(* BOX_TYPE = "PRIMITIVE" *) 
   BUFG clkout2_buf
       (.I(CLK_200i_mmcm0),
        .O(CLK_200i));
(* BOX_TYPE = "PRIMITIVE" *) 
   BUFG clkout3_buf
       (.I(CLK_166i_mmcm0),
        .O(CLK_166i));
(* BOX_TYPE = "PRIMITIVE" *) 
   MMCME2_ADV #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT_F(10.000000),
    .CLKFBOUT_PHASE(0.000000),
    .CLKFBOUT_USE_FINE_PS("FALSE"),
    .CLKIN1_PERIOD(10.000000),
    .CLKIN2_PERIOD(0.000000),
    .CLKOUT0_DIVIDE_F(10.000000),
    .CLKOUT0_DUTY_CYCLE(0.500000),
    .CLKOUT0_PHASE(0.000000),
    .CLKOUT0_USE_FINE_PS("FALSE"),
    .CLKOUT1_DIVIDE(5),
    .CLKOUT1_DUTY_CYCLE(0.500000),
    .CLKOUT1_PHASE(0.000000),
    .CLKOUT1_USE_FINE_PS("FALSE"),
    .CLKOUT2_DIVIDE(6),
    .CLKOUT2_DUTY_CYCLE(0.500000),
    .CLKOUT2_PHASE(0.000000),
    .CLKOUT2_USE_FINE_PS("FALSE"),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.500000),
    .CLKOUT3_PHASE(0.000000),
    .CLKOUT3_USE_FINE_PS("FALSE"),
    .CLKOUT4_CASCADE("FALSE"),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.500000),
    .CLKOUT4_PHASE(0.000000),
    .CLKOUT4_USE_FINE_PS("FALSE"),
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.500000),
    .CLKOUT5_PHASE(0.000000),
    .CLKOUT5_USE_FINE_PS("FALSE"),
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.500000),
    .CLKOUT6_PHASE(0.000000),
    .CLKOUT6_USE_FINE_PS("FALSE"),
    .COMPENSATION("ZHOLD"),
    .DIVCLK_DIVIDE(1),
    .IS_CLKINSEL_INVERTED(1'b0),
    .IS_PSEN_INVERTED(1'b0),
    .IS_PSINCDEC_INVERTED(1'b0),
    .IS_PWRDWN_INVERTED(1'b0),
    .IS_RST_INVERTED(1'b0),
    .REF_JITTER1(0.010000),
    .REF_JITTER2(0.010000),
    .SS_EN("FALSE"),
    .SS_MODE("CENTER_HIGH"),
    .SS_MOD_PERIOD(10000),
    .STARTUP_WAIT("FALSE")) 
     mmcm_adv_inst
       (.CLKFBIN(clkfbout_buf_mmcm0),
        .CLKFBOUT(clkfbout_mmcm0),
        .CLKIN1(CLK_100_mmcm0),
        .CLKIN2(\<const0> ),
        .CLKINSEL(\<const1> ),
        .CLKOUT0(CLK_100i_mmcm0),
        .CLKOUT1(CLK_200i_mmcm0),
        .CLKOUT2(CLK_166i_mmcm0),
        .DADDR({\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> }),
        .DCLK(\<const0> ),
        .DEN(\<const0> ),
        .DI({\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> ,\<const0> }),
        .DWE(\<const0> ),
        .PSCLK(\<const0> ),
        .PSEN(\<const0> ),
        .PSINCDEC(\<const0> ),
        .PWRDWN(\<const0> ),
        .RST(\<const0> ));
endmodule

module mux2
   (din_0,
    din_1,
    sel,
    mux_out);
  input din_0;
  input din_1;
  input sel;
  output mux_out;

  wire din_0;
  wire din_1;
  wire mux_out;
  wire sel;

LUT3 #(
    .INIT(8'hB8)) 
     mux_out_INST_0
       (.I0(din_1),
        .I1(sel),
        .I2(din_0),
        .O(mux_out));
endmodule
