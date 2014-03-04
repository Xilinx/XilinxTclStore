
Ç
$Using Tcl App repository from '%s'.
323*common2C
//home/bdai/.Xilinx/Vivado/2014.2/XilinxTclStore2default:defaultZ17-362
ì
Sourcing tcl script '%s'
201*common2_
K/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/prep/rdi/vivado/scripts/init.tcl2default:defaultZ17-201
t
Command: %s
53*	vivadotcl2L
8synth_design -top ff_replicator -part xc7vx485tffg1157-12default:defaultZ4-113
/

Starting synthesis...

3*	vivadotclZ4-3
ó
@Attempting to get a license for feature '%s' and/or device '%s'
308*common2
	Synthesis2default:default2
	xc7vx485t2default:defaultZ17-347
á
0Got license for feature '%s' and/or device '%s'
310*common2
	Synthesis2default:default2
	xc7vx485t2default:defaultZ17-349
ú
%s*synth2å
xStarting RTL Elaboration : Time (s): cpu = 00:00:05 ; elapsed = 00:00:05 . Memory (MB): peak = 797.781 ; gain = 194.246
2default:default
Ë
synthesizing module '%s'638*oasys2!
ff_replicator2default:default2w
a/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.v2default:default2
12default:default8@Z8-638
R
%s*synth2C
/	Parameter WIDTH bound to: 10 - type: integer 
2default:default
S
%s*synth2D
0	Parameter STAGES bound to: 10 - type: integer 
2default:default
Í
synthesizing module '%s'638*oasys2"
ff_ce_sync_rst2default:default2x
b/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_ce_sync_rst.v2default:default2
12default:default8@Z8-638
V
%s*synth2G
3	Parameter INIT_VALUE bound to: 0 - type: integer 
2default:default
•
%done synthesizing module '%s' (%s#%s)256*oasys2"
ff_ce_sync_rst2default:default2
12default:default2
12default:default2x
b/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_ce_sync_rst.v2default:default2
12default:default8@Z8-256
£
%done synthesizing module '%s' (%s#%s)256*oasys2!
ff_replicator2default:default2
22default:default2
12default:default2w
a/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.v2default:default2
12default:default8@Z8-256
ú
%s*synth2å
xFinished RTL Elaboration : Time (s): cpu = 00:00:05 ; elapsed = 00:00:06 . Memory (MB): peak = 832.844 ; gain = 229.309
2default:default
;
%s*synth2,

Report Check Netlist: 
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
l
%s*synth2]
I|      |Item              |Errors |Warnings |Status |Description       |
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
l
%s*synth2]
I|1     |multi_driven_nets |      0|        0|Passed |Multi driven nets |
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
±
Loading clock regions from %s
13*device2z
f/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/virtex7/xc7vx485t/ClockRegion.xml2default:defaultZ21-13
≤
Loading clock buffers from %s
11*device2{
g/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/virtex7/xc7vx485t/ClockBuffers.xml2default:defaultZ21-11
≠
&Loading clock placement rules from %s
318*place2m
Y/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/ClockPlacerRules.xml2default:defaultZ30-318
´
)Loading package pin functions from %s...
17*device2i
U/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/PinFunctions.xml2default:defaultZ21-17
Ø
Loading package from %s
16*device2~
j/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/virtex7/xc7vx485t/ffg1157/Package.xml2default:defaultZ21-16
†
Loading io standards from %s
15*device2j
V/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/./parts/xilinx/virtex7/IOStandards.xml2default:defaultZ21-15
¨
+Loading device configuration modes from %s
14*device2h
T/proj/rdi-xsj/staff/bdai/hd2/tclstore/HEAD/data/parts/xilinx/virtex7/ConfigModes.xml2default:defaultZ21-14
U
Feature available: %s
81*common2&
Internal_bitstream2default:defaultZ17-81
5

Processing XDC Constraints
244*projectZ1-262
≠
Parsing XDC File [%s]
179*designutils2w
c/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.xdc2default:defaultZ20-179
∂
Finished Parsing XDC File [%s]
178*designutils2w
c/wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.xdc2default:defaultZ20-178
?
&Completed Processing XDC Constraints

245*projectZ1-263
u
!Unisim Transformation Summary:
%s111*project29
%No Unisim elements were transformed.
2default:defaultZ1-111
≤
%s*synth2¢
çFinished Loading Part and Timing Information : Time (s): cpu = 00:00:20 ; elapsed = 00:00:21 . Memory (MB): peak = 1151.215 ; gain = 547.680
2default:default
∂
%s*synth2¶
ëFinished applying 'set_property' XDC Constraints : Time (s): cpu = 00:00:20 ; elapsed = 00:00:22 . Memory (MB): peak = 1151.215 ; gain = 547.680
2default:default
û
%s*synth2é
zFinished RTL Optimization : Time (s): cpu = 00:00:20 ; elapsed = 00:00:22 . Memory (MB): peak = 1151.215 ; gain = 547.680
2default:default
<
%s*synth2-

Report RTL Partitions: 
2default:default
N
%s*synth2?
++-+--------------+------------+----------+
2default:default
N
%s*synth2?
+| |RTL Partition |Replication |Instances |
2default:default
N
%s*synth2?
++-+--------------+------------+----------+
2default:default
N
%s*synth2?
++-+--------------+------------+----------+
2default:default
B
%s*synth23
Detailed RTL Component Info : 
2default:default
4
%s*synth2%
+---Registers : 
2default:default
Q
%s*synth2B
.	                1 Bit    Registers := 100   
2default:default
F
%s*synth27
#Hierarchical RTL Component report 
2default:default
9
%s*synth2*
Module ff_replicator 
2default:default
B
%s*synth23
Detailed RTL Component Info : 
2default:default
:
%s*synth2+
Module ff_ce_sync_rst 
2default:default
B
%s*synth23
Detailed RTL Component Info : 
2default:default
4
%s*synth2%
+---Registers : 
2default:default
Q
%s*synth2B
.	                1 Bit    Registers := 1     
2default:default
~
%s*synth2o
[Part Resources:
DSPs: 2800 (col length:140)
BRAMs: 2060 (col length: RAMB18 140 RAMB36 70)
2default:default
™
%s*synth2ö
ÖFinished Cross Boundary Optimization : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1210.207 ; gain = 606.672
2default:default
¢
%s*synth2í
~---------------------------------------------------------------------------------
Start RAM, DSP and Shift Register Reporting
2default:default
u
%s*synth2f
R---------------------------------------------------------------------------------
2default:default
¶
%s*synth2ñ
Å---------------------------------------------------------------------------------
Finished RAM, DSP and Shift Register Reporting
2default:default
u
%s*synth2f
R---------------------------------------------------------------------------------
2default:default
ü
%s*synth2è
{Finished Area Optimization : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1210.207 ; gain = 606.672
2default:default
Æ
%s*synth2û
âFinished Applying XDC Timing Constraints : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1210.207 ; gain = 606.672
2default:default
°
%s*synth2ë
}Finished Timing Optimization : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1210.207 ; gain = 606.672
2default:default
†
%s*synth2ê
|Finished Technology Mapping : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
ö
%s*synth2ä
vFinished IO Insertion : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
;
%s*synth2,

Report Check Netlist: 
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
l
%s*synth2]
I|      |Item              |Errors |Warnings |Status |Description       |
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
l
%s*synth2]
I|1     |multi_driven_nets |      0|        0|Passed |Multi driven nets |
2default:default
l
%s*synth2]
I+------+------------------+-------+---------+-------+------------------+
2default:default
´
%s*synth2õ
ÜFinished Renaming Generated Instances : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
®
%s*synth2ò
ÉFinished Rebuilding User Hierarchy : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
¢
%s*synth2í
~---------------------------------------------------------------------------------
Start RAM, DSP and Shift Register Reporting
2default:default
u
%s*synth2f
R---------------------------------------------------------------------------------
2default:default
¶
%s*synth2ñ
Å---------------------------------------------------------------------------------
Finished RAM, DSP and Shift Register Reporting
2default:default
u
%s*synth2f
R---------------------------------------------------------------------------------
2default:default
8
%s*synth2)

Report BlackBoxes: 
2default:default
A
%s*synth22
+-+--------------+----------+
2default:default
A
%s*synth22
| |BlackBox name |Instances |
2default:default
A
%s*synth22
+-+--------------+----------+
2default:default
A
%s*synth22
+-+--------------+----------+
2default:default
8
%s*synth2)

Report Cell Usage: 
2default:default
9
%s*synth2*
+------+-----+------+
2default:default
9
%s*synth2*
|      |Cell |Count |
2default:default
9
%s*synth2*
+------+-----+------+
2default:default
9
%s*synth2*
|1     |BUFG |     1|
2default:default
9
%s*synth2*
|2     |FDRE |   100|
2default:default
9
%s*synth2*
|3     |IBUF |    13|
2default:default
9
%s*synth2*
|4     |OBUF |    10|
2default:default
9
%s*synth2*
+------+-----+------+
2default:default
<
%s*synth2-

Report Instance Areas: 
2default:default
h
%s*synth2Y
E+------+---------------------------------+------------------+------+
2default:default
h
%s*synth2Y
E|      |Instance                         |Module            |Cells |
2default:default
h
%s*synth2Y
E+------+---------------------------------+------------------+------+
2default:default
h
%s*synth2Y
E|1     |top                              |                  |   124|
2default:default
h
%s*synth2Y
E|2     |  \ff_stage[0].ff_channel[0].ff  |ff_ce_sync_rst    |     1|
2default:default
h
%s*synth2Y
E|3     |  \ff_stage[0].ff_channel[1].ff  |ff_ce_sync_rst_0  |     1|
2default:default
h
%s*synth2Y
E|4     |  \ff_stage[0].ff_channel[2].ff  |ff_ce_sync_rst_1  |     1|
2default:default
h
%s*synth2Y
E|5     |  \ff_stage[0].ff_channel[3].ff  |ff_ce_sync_rst_2  |     1|
2default:default
h
%s*synth2Y
E|6     |  \ff_stage[0].ff_channel[4].ff  |ff_ce_sync_rst_3  |     1|
2default:default
h
%s*synth2Y
E|7     |  \ff_stage[0].ff_channel[5].ff  |ff_ce_sync_rst_4  |     1|
2default:default
h
%s*synth2Y
E|8     |  \ff_stage[0].ff_channel[6].ff  |ff_ce_sync_rst_5  |     1|
2default:default
h
%s*synth2Y
E|9     |  \ff_stage[0].ff_channel[7].ff  |ff_ce_sync_rst_6  |     1|
2default:default
h
%s*synth2Y
E|10    |  \ff_stage[0].ff_channel[8].ff  |ff_ce_sync_rst_7  |     1|
2default:default
h
%s*synth2Y
E|11    |  \ff_stage[0].ff_channel[9].ff  |ff_ce_sync_rst_8  |     1|
2default:default
h
%s*synth2Y
E|12    |  \ff_stage[1].ff_channel[0].ff  |ff_ce_sync_rst_9  |     1|
2default:default
h
%s*synth2Y
E|13    |  \ff_stage[1].ff_channel[1].ff  |ff_ce_sync_rst_10 |     1|
2default:default
h
%s*synth2Y
E|14    |  \ff_stage[1].ff_channel[2].ff  |ff_ce_sync_rst_11 |     1|
2default:default
h
%s*synth2Y
E|15    |  \ff_stage[1].ff_channel[3].ff  |ff_ce_sync_rst_12 |     1|
2default:default
h
%s*synth2Y
E|16    |  \ff_stage[1].ff_channel[4].ff  |ff_ce_sync_rst_13 |     1|
2default:default
h
%s*synth2Y
E|17    |  \ff_stage[1].ff_channel[5].ff  |ff_ce_sync_rst_14 |     1|
2default:default
h
%s*synth2Y
E|18    |  \ff_stage[1].ff_channel[6].ff  |ff_ce_sync_rst_15 |     1|
2default:default
h
%s*synth2Y
E|19    |  \ff_stage[1].ff_channel[7].ff  |ff_ce_sync_rst_16 |     1|
2default:default
h
%s*synth2Y
E|20    |  \ff_stage[1].ff_channel[8].ff  |ff_ce_sync_rst_17 |     1|
2default:default
h
%s*synth2Y
E|21    |  \ff_stage[1].ff_channel[9].ff  |ff_ce_sync_rst_18 |     1|
2default:default
h
%s*synth2Y
E|22    |  \ff_stage[2].ff_channel[0].ff  |ff_ce_sync_rst_19 |     1|
2default:default
h
%s*synth2Y
E|23    |  \ff_stage[2].ff_channel[1].ff  |ff_ce_sync_rst_20 |     1|
2default:default
h
%s*synth2Y
E|24    |  \ff_stage[2].ff_channel[2].ff  |ff_ce_sync_rst_21 |     1|
2default:default
h
%s*synth2Y
E|25    |  \ff_stage[2].ff_channel[3].ff  |ff_ce_sync_rst_22 |     1|
2default:default
h
%s*synth2Y
E|26    |  \ff_stage[2].ff_channel[4].ff  |ff_ce_sync_rst_23 |     1|
2default:default
h
%s*synth2Y
E|27    |  \ff_stage[2].ff_channel[5].ff  |ff_ce_sync_rst_24 |     1|
2default:default
h
%s*synth2Y
E|28    |  \ff_stage[2].ff_channel[6].ff  |ff_ce_sync_rst_25 |     1|
2default:default
h
%s*synth2Y
E|29    |  \ff_stage[2].ff_channel[7].ff  |ff_ce_sync_rst_26 |     1|
2default:default
h
%s*synth2Y
E|30    |  \ff_stage[2].ff_channel[8].ff  |ff_ce_sync_rst_27 |     1|
2default:default
h
%s*synth2Y
E|31    |  \ff_stage[2].ff_channel[9].ff  |ff_ce_sync_rst_28 |     1|
2default:default
h
%s*synth2Y
E|32    |  \ff_stage[3].ff_channel[0].ff  |ff_ce_sync_rst_29 |     1|
2default:default
h
%s*synth2Y
E|33    |  \ff_stage[3].ff_channel[1].ff  |ff_ce_sync_rst_30 |     1|
2default:default
h
%s*synth2Y
E|34    |  \ff_stage[3].ff_channel[2].ff  |ff_ce_sync_rst_31 |     1|
2default:default
h
%s*synth2Y
E|35    |  \ff_stage[3].ff_channel[3].ff  |ff_ce_sync_rst_32 |     1|
2default:default
h
%s*synth2Y
E|36    |  \ff_stage[3].ff_channel[4].ff  |ff_ce_sync_rst_33 |     1|
2default:default
h
%s*synth2Y
E|37    |  \ff_stage[3].ff_channel[5].ff  |ff_ce_sync_rst_34 |     1|
2default:default
h
%s*synth2Y
E|38    |  \ff_stage[3].ff_channel[6].ff  |ff_ce_sync_rst_35 |     1|
2default:default
h
%s*synth2Y
E|39    |  \ff_stage[3].ff_channel[7].ff  |ff_ce_sync_rst_36 |     1|
2default:default
h
%s*synth2Y
E|40    |  \ff_stage[3].ff_channel[8].ff  |ff_ce_sync_rst_37 |     1|
2default:default
h
%s*synth2Y
E|41    |  \ff_stage[3].ff_channel[9].ff  |ff_ce_sync_rst_38 |     1|
2default:default
h
%s*synth2Y
E|42    |  \ff_stage[4].ff_channel[0].ff  |ff_ce_sync_rst_39 |     1|
2default:default
h
%s*synth2Y
E|43    |  \ff_stage[4].ff_channel[1].ff  |ff_ce_sync_rst_40 |     1|
2default:default
h
%s*synth2Y
E|44    |  \ff_stage[4].ff_channel[2].ff  |ff_ce_sync_rst_41 |     1|
2default:default
h
%s*synth2Y
E|45    |  \ff_stage[4].ff_channel[3].ff  |ff_ce_sync_rst_42 |     1|
2default:default
h
%s*synth2Y
E|46    |  \ff_stage[4].ff_channel[4].ff  |ff_ce_sync_rst_43 |     1|
2default:default
h
%s*synth2Y
E|47    |  \ff_stage[4].ff_channel[5].ff  |ff_ce_sync_rst_44 |     1|
2default:default
h
%s*synth2Y
E|48    |  \ff_stage[4].ff_channel[6].ff  |ff_ce_sync_rst_45 |     1|
2default:default
h
%s*synth2Y
E|49    |  \ff_stage[4].ff_channel[7].ff  |ff_ce_sync_rst_46 |     1|
2default:default
h
%s*synth2Y
E|50    |  \ff_stage[4].ff_channel[8].ff  |ff_ce_sync_rst_47 |     1|
2default:default
h
%s*synth2Y
E|51    |  \ff_stage[4].ff_channel[9].ff  |ff_ce_sync_rst_48 |     1|
2default:default
h
%s*synth2Y
E|52    |  \ff_stage[5].ff_channel[0].ff  |ff_ce_sync_rst_49 |     1|
2default:default
h
%s*synth2Y
E|53    |  \ff_stage[5].ff_channel[1].ff  |ff_ce_sync_rst_50 |     1|
2default:default
h
%s*synth2Y
E|54    |  \ff_stage[5].ff_channel[2].ff  |ff_ce_sync_rst_51 |     1|
2default:default
h
%s*synth2Y
E|55    |  \ff_stage[5].ff_channel[3].ff  |ff_ce_sync_rst_52 |     1|
2default:default
h
%s*synth2Y
E|56    |  \ff_stage[5].ff_channel[4].ff  |ff_ce_sync_rst_53 |     1|
2default:default
h
%s*synth2Y
E|57    |  \ff_stage[5].ff_channel[5].ff  |ff_ce_sync_rst_54 |     1|
2default:default
h
%s*synth2Y
E|58    |  \ff_stage[5].ff_channel[6].ff  |ff_ce_sync_rst_55 |     1|
2default:default
h
%s*synth2Y
E|59    |  \ff_stage[5].ff_channel[7].ff  |ff_ce_sync_rst_56 |     1|
2default:default
h
%s*synth2Y
E|60    |  \ff_stage[5].ff_channel[8].ff  |ff_ce_sync_rst_57 |     1|
2default:default
h
%s*synth2Y
E|61    |  \ff_stage[5].ff_channel[9].ff  |ff_ce_sync_rst_58 |     1|
2default:default
h
%s*synth2Y
E|62    |  \ff_stage[6].ff_channel[0].ff  |ff_ce_sync_rst_59 |     1|
2default:default
h
%s*synth2Y
E|63    |  \ff_stage[6].ff_channel[1].ff  |ff_ce_sync_rst_60 |     1|
2default:default
h
%s*synth2Y
E|64    |  \ff_stage[6].ff_channel[2].ff  |ff_ce_sync_rst_61 |     1|
2default:default
h
%s*synth2Y
E|65    |  \ff_stage[6].ff_channel[3].ff  |ff_ce_sync_rst_62 |     1|
2default:default
h
%s*synth2Y
E|66    |  \ff_stage[6].ff_channel[4].ff  |ff_ce_sync_rst_63 |     1|
2default:default
h
%s*synth2Y
E|67    |  \ff_stage[6].ff_channel[5].ff  |ff_ce_sync_rst_64 |     1|
2default:default
h
%s*synth2Y
E|68    |  \ff_stage[6].ff_channel[6].ff  |ff_ce_sync_rst_65 |     1|
2default:default
h
%s*synth2Y
E|69    |  \ff_stage[6].ff_channel[7].ff  |ff_ce_sync_rst_66 |     1|
2default:default
h
%s*synth2Y
E|70    |  \ff_stage[6].ff_channel[8].ff  |ff_ce_sync_rst_67 |     1|
2default:default
h
%s*synth2Y
E|71    |  \ff_stage[6].ff_channel[9].ff  |ff_ce_sync_rst_68 |     1|
2default:default
h
%s*synth2Y
E|72    |  \ff_stage[7].ff_channel[0].ff  |ff_ce_sync_rst_69 |     1|
2default:default
h
%s*synth2Y
E|73    |  \ff_stage[7].ff_channel[1].ff  |ff_ce_sync_rst_70 |     1|
2default:default
h
%s*synth2Y
E|74    |  \ff_stage[7].ff_channel[2].ff  |ff_ce_sync_rst_71 |     1|
2default:default
h
%s*synth2Y
E|75    |  \ff_stage[7].ff_channel[3].ff  |ff_ce_sync_rst_72 |     1|
2default:default
h
%s*synth2Y
E|76    |  \ff_stage[7].ff_channel[4].ff  |ff_ce_sync_rst_73 |     1|
2default:default
h
%s*synth2Y
E|77    |  \ff_stage[7].ff_channel[5].ff  |ff_ce_sync_rst_74 |     1|
2default:default
h
%s*synth2Y
E|78    |  \ff_stage[7].ff_channel[6].ff  |ff_ce_sync_rst_75 |     1|
2default:default
h
%s*synth2Y
E|79    |  \ff_stage[7].ff_channel[7].ff  |ff_ce_sync_rst_76 |     1|
2default:default
h
%s*synth2Y
E|80    |  \ff_stage[7].ff_channel[8].ff  |ff_ce_sync_rst_77 |     1|
2default:default
h
%s*synth2Y
E|81    |  \ff_stage[7].ff_channel[9].ff  |ff_ce_sync_rst_78 |     1|
2default:default
h
%s*synth2Y
E|82    |  \ff_stage[8].ff_channel[0].ff  |ff_ce_sync_rst_79 |     1|
2default:default
h
%s*synth2Y
E|83    |  \ff_stage[8].ff_channel[1].ff  |ff_ce_sync_rst_80 |     1|
2default:default
h
%s*synth2Y
E|84    |  \ff_stage[8].ff_channel[2].ff  |ff_ce_sync_rst_81 |     1|
2default:default
h
%s*synth2Y
E|85    |  \ff_stage[8].ff_channel[3].ff  |ff_ce_sync_rst_82 |     1|
2default:default
h
%s*synth2Y
E|86    |  \ff_stage[8].ff_channel[4].ff  |ff_ce_sync_rst_83 |     1|
2default:default
h
%s*synth2Y
E|87    |  \ff_stage[8].ff_channel[5].ff  |ff_ce_sync_rst_84 |     1|
2default:default
h
%s*synth2Y
E|88    |  \ff_stage[8].ff_channel[6].ff  |ff_ce_sync_rst_85 |     1|
2default:default
h
%s*synth2Y
E|89    |  \ff_stage[8].ff_channel[7].ff  |ff_ce_sync_rst_86 |     1|
2default:default
h
%s*synth2Y
E|90    |  \ff_stage[8].ff_channel[8].ff  |ff_ce_sync_rst_87 |     1|
2default:default
h
%s*synth2Y
E|91    |  \ff_stage[8].ff_channel[9].ff  |ff_ce_sync_rst_88 |     1|
2default:default
h
%s*synth2Y
E|92    |  \ff_stage[9].ff_channel[0].ff  |ff_ce_sync_rst_89 |     1|
2default:default
h
%s*synth2Y
E|93    |  \ff_stage[9].ff_channel[1].ff  |ff_ce_sync_rst_90 |     1|
2default:default
h
%s*synth2Y
E|94    |  \ff_stage[9].ff_channel[2].ff  |ff_ce_sync_rst_91 |     1|
2default:default
h
%s*synth2Y
E|95    |  \ff_stage[9].ff_channel[3].ff  |ff_ce_sync_rst_92 |     1|
2default:default
h
%s*synth2Y
E|96    |  \ff_stage[9].ff_channel[4].ff  |ff_ce_sync_rst_93 |     1|
2default:default
h
%s*synth2Y
E|97    |  \ff_stage[9].ff_channel[5].ff  |ff_ce_sync_rst_94 |     1|
2default:default
h
%s*synth2Y
E|98    |  \ff_stage[9].ff_channel[6].ff  |ff_ce_sync_rst_95 |     1|
2default:default
h
%s*synth2Y
E|99    |  \ff_stage[9].ff_channel[7].ff  |ff_ce_sync_rst_96 |     1|
2default:default
h
%s*synth2Y
E|100   |  \ff_stage[9].ff_channel[8].ff  |ff_ce_sync_rst_97 |     1|
2default:default
h
%s*synth2Y
E|101   |  \ff_stage[9].ff_channel[9].ff  |ff_ce_sync_rst_98 |     1|
2default:default
h
%s*synth2Y
E+------+---------------------------------+------------------+------+
2default:default
ß
%s*synth2ó
ÇFinished Writing Synthesis Report : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
i
%s*synth2Z
FSynthesis finished with 0 errors, 0 critical warnings and 0 warnings.
2default:default
•
%s*synth2ï
ÄSynthesis Optimization Complete : Time (s): cpu = 00:00:33 ; elapsed = 00:00:34 . Memory (MB): peak = 1220.223 ; gain = 616.688
2default:default
]
-Analyzing %s Unisim elements for replacement
17*netlist2
132default:defaultZ29-17
a
2Unisim Transformation completed in %s CPU seconds
28*netlist2
02default:defaultZ29-28
^
1Inserted %s IBUFs to IO ports without IO buffers.100*opt2
02default:defaultZ31-140
^
1Inserted %s OBUFs to IO ports without IO buffers.101*opt2
02default:defaultZ31-141
C
Pushed %s inverter(s).
98*opt2
02default:defaultZ31-138
u
!Unisim Transformation Summary:
%s111*project29
%No Unisim elements were transformed.
2default:defaultZ1-111
L
Releasing license: %s
83*common2
	Synthesis2default:defaultZ17-83
Ω
G%s Infos, %s Warnings, %s Critical Warnings and %s Errors encountered.
28*	vivadotcl2
132default:default2
02default:default2
02default:default2
02default:defaultZ4-41
U
%s completed successfully
29*	vivadotcl2 
synth_design2default:defaultZ4-42
˝
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2"
synth_design: 2default:default2
00:00:332default:default2
00:00:342default:default2
1229.2232default:default2
484.4102default:defaultZ17-268
Ç
vreport_utilization: Time (s): cpu = 00:00:00.06 ; elapsed = 00:00:00.10 . Memory (MB): peak = 1229.254 ; gain = 0.000
*common
w
Exiting %s at %s...
206*common2
Vivado2default:default2,
Tue Mar  4 10:06:01 20142default:defaultZ17-206