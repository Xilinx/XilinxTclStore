*************************************************************************
   ____  ____ 
  /   /\/   / 
 /___/  \  /   
 \   \   \/    © Copyright 2013 Xilinx, Inc. All rights reserved.
  \   \        This file contains confidential and proprietary 
  /   /        information of Xilinx, Inc. and is protected under U.S. 
 /___/   /\    and international copyright and other intellectual 
 \   \  /  \   property laws. 
  \___\/\___\ 
 
*************************************************************************

Vendor: Xilinx 
Current readme.txt Version: <2013.3>
Date Last Modified:  <10/01/2013> (e.g., 21JAN2013)
Date Created: <10/01/2013>

Associated Filename: xtp302-design-methodology-tcl-files.zip 
Associated Document: UG949: UltraFast(TM) Design Methodology Guide for the Vivado(R) Design Suite

Supported Device(s): <Include appropriate devices, e.g., Virtex-6 CXT/LXT/HXT/SXT FPGAs, 
Spartan-6 LX/LXT FPGAs, Virtex-5 LX/LXT/SXT/TXT/FXT FPGAs, Kintex-7 FPGAs>
   
*************************************************************************

Disclaimer: 

      This disclaimer is not a license and does not grant any rights to 
      the materials distributed herewith. Except as otherwise provided in 
      a valid license issued to you by Xilinx, and to the maximum extent 
      permitted by applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE 
      "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL 
      WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
      INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, 
      NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and 
      (2) Xilinx shall not be liable (whether in contract or tort, 
      including negligence, or under any other theory of liability) for 
      any loss or damage of any kind or nature related to, arising under 
      or in connection with these materials, including for any direct, or 
      any indirect, special, incidental, or consequential loss or damage 
      (including loss of data, profits, goodwill, or any type of loss or 
      damage suffered as a result of any action brought by a third party) 
      even if such damage or loss was reasonably foreseeable or Xilinx 
      had been advised of the possibility of the same.

Critical Applications:

      Xilinx products are not designed or intended to be fail-safe, or 
      for use in any application requiring fail-safe performance, such as 
      life-support or safety devices or systems, Class III medical 
      devices, nuclear facilities, applications related to the deployment 
      of airbags, or any other applications that could lead to death, 
      personal injury, or severe property or environmental damage 
      (individually and collectively, "Critical Applications"). Customer 
      assumes the sole risk and liability of any use of Xilinx products 
      in Critical Applications, subject only to applicable laws and 
      regulations governing limitations on product liability.

THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS 
FILE AT ALL TIMES.

*************************************************************************

This readme file contains these sections:

1. REVISION HISTORY
2. OVERVIEW
3. SOFTWARE TOOLS AND SYSTEM REQUIREMENTS
4. DESIGN FILE HIERARCHY
5. INSTALLATION AND OPERATING INSTRUCTIONS
6. OTHER INFORMATION (OPTIONAL)
7. SUPPORT


1. REVISION HISTORY 



            Readme  
Date        Version      Revision Description
=========================================================================
10/23/2013   2013.3          Initial Xilinx release.

=========================================================================



2. OVERVIEW

This readme describes how to use the files that come with UG949, UltraFast Design Methodology Guide for the Vivado Design Suite 

<Add any other introductory material here, for example:>




3. SOFTWARE TOOLS AND SYSTEM REQUIREMENTS

<List software tools used for testing and validatation. List such system 
requirements as operating systems, version of third party software, 
hardware requirements (i.e., processor speed and memory space), etc.>

<For example:>
* Xilinx Vivado 2013.3 or higher


4. DESIGN FILE HIERARCHY

<Describe the file hierarchy by type (HDL files, simulation files, etc.)>

<For example:>
The directory structure underneath this top-level folder is described 
below:

\ChipScope_Projects
 |   This folder contains project files for the ChipScope Pro analyzer, 
 |   one .prj file for each of the demos included in this release.
 |       
\Source
 |
 +-----  \[Verilog,VHDL]
 |       The Verilog\ and VHDL\ directories contain the Verilog and VHDL 
 |       source code for the triple-rate SDI reference design and demos. 
 |    
 |           +--\dru
 |              Contains the files for the data recovery unit. The HDL
 |              files must be added to the project. The dru.ngc file
 |              contains the pre-synthesized DRU. It must be placed in 
 |              the ISE project directory where the ISE tools can 
 |              include it in the project design.
 |
 |           +--\misc_source
 |              Contains source code for modules common to all demos.
 |
 |           +--\pass_demo
 |              Contains files specific to the SDI demo.
 |
 |           +--\V6_SDI
                Contains all source code files needed for SDI receivers
	        and SDI transmitters, except for the SD-SDI DRU files.


5. INSTALLATION AND OPERATING INSTRUCTIONS 

<Provide the instructions needed to run the design here>

<For example:>
1) Install the Xilinx Vivado 2013.1 or later tools.
2) Download Eclipse from http://www.eclipse.org/downloads/ and install.
3) Download SimplifIDE from http://www.eclipseplugincentral.com.
   a) Type "VHDL" in the search box and click the [Search] button.
   b) From the search results, select "VHDL and Verilog Plugin."
   c) Click the Install button.

To incorporate the <insert name here> module into a Vivado tools design project:

Verilog flow:

1) 
2) 

VHDL flow:

1) 
2) 


6. OTHER INFORMATION (OPTIONAL) 

<Include design notes that the designer needs to know about, such as 
limitations, warnings, known issues, or fixes>

<For example:>
1) Warnings
      Memory collision error

	When simulating the demo, this ModelSim warning might be seen:
    
    	** Warning:  Memory Collision on RAMB16_S*_S*: :ll_fifo_tb:*: 
        at simulation time *** ns.

        This message occurs because ...
        However, this situation is okay because ... 

2) Design Notes
	The files in this reference design are to be used with XST.
	Some contain XST-specific constraints that need to be translated
	if a different synthesizer is used.

3) Fixes
	(1) Fixed a bug that concatenates two frames together when the
            FIFO oscillates between empty and non-empty. 

4) Known Issues
	(1) These files might not work correctly on the limited early ES
	    (silicon version 1.0) LX240T devices. 


7. SUPPORT

To obtain technical support for this reference design, go to 
www.xilinx.com/support to locate answers to known issues in the Xilinx
Answers Database or to create a WebCase.  