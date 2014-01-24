####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
#
# Date Created     :  01/01/2014
# Script name      :  register_options.tcl
# Tool Version     :  Vivado 2014.1
# Description      :  Setup "Vivado Simulator" options on the simulation fileset
# Revision History :
#   01/01/2014 1.0  - Initial version
#
####################################################################################################
package require Vivado 2013.1
namespace eval ::tclapp::xilinx::xsim {
proc register_options { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable options
  if { {} == $simulator } {
    send_msg_id Vivado-XSim-999 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id Vivado-XSim-999 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }
  # simulation fileset object on which the options will be created and value set
  set fs_obj [current_fileset -simset]
  set options {
    {{compile.xvlog.nosort}        {bool}   {0}                                                  {Donot sort}}
    {{compile.xvlog.more_options}  {string} {}                                                   {More Xvlog compilation Options}}
    {{compile.xvhdl.more_options}  {string} {}                                                   {More Xvhdl Compilation Options}}
    {{elaborate.snapshot}          {string} {}                                                   {Specify name of the simulation snapshot}}
    {{elaborate.dll}               {bool}   {0}                                                  {Generate DLL file}}
    {{elaborate.debug_level}       {enum}   {{typical} {typical} {{all} {typical} {off}}}        {Specify simulation debug visibility level}}
    {{elaborate.relax}             {bool}   {1}                                                  {Relax}}
    {{elaborate.mt_level}          {enum}   {{auto} {auto} {{auto} {off} {2} {4} {8} {16} {32}}} {Specify number of sub-compilation jobs to run in parallel}}
    {{elaborate.load_glbl}         {bool}   {1}                                                  {Load GLBL module}}
    {{elaborate.rangecheck}        {bool}   {0}                                                  {Enable runtime value range check for VHDL}}
    {{elaborate.sdf_delay}         {enum}   {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}}              {Specify SDF timing delay type to be read for use in timing simulation}}
    {{elaborate.unifast}           {bool}   {0}                                                  {Enable fast simulation models}}
    {{elaborate.more_options}      {string} {}                                                   {More Elaboration Options}}
    {{simulate.wdb}                {string} {}                                                   {Specify Waveform Database file}}
    {{simulate.saif}               {string} {}                                                   {SAIF Filename}}
    {{simulate.tclbatch}           {string} {}                                                   {Specify custom command file for simulation}}
    {{simulate.view}               {string} {}                                                   {Specify Waveform Configuration file}}
    {{simulate.more_options}       {string} {}                                                   {More Simulation Options}}
  }
  # create options
  ::tclapp::xilinx::simutils::usf_create_options $simulator $options
  return 0
}
}
