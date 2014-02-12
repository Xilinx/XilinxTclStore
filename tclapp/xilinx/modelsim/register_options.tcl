####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
#
# Date Created     :  01/01/2014
# Script name      :  register_options.tcl
# Tool Version     :  Vivado 2014.1
# Description      :  Setup "ModelSim/Questa" simulator options on the simulation fileset
# Revision History :
#   01/01/2014 1.0  - Initial version
#
####################################################################################################
package require Vivado 2013.1
package require ::tclapp::xilinx::modelsim::helpers

namespace eval ::tclapp::xilinx::modelsim {
proc register_options { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable options
  if { {} == $simulator } {
    send_msg_id Vivado-ModelSim-999 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id Vivado-ModelSim-999 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }
  # simulation fileset object on which the options will be created and value set
  set fs_obj [current_fileset -simset]
  set options {
    {{compile.vhdl_syntax}        {enum}   {{93} {93} {{93} {87} {2002} {2008}}}   {Specify VHDL syntax}}
    {{compile.use_explicit_decl}  {bool}   {1}                                     {Log all signals}}
    {{compile.log_all_signals}    {bool}   {0}                                     {Log all signals}}
    {{compile.load_glbl}          {bool}   {1}                                     {Load GLBL module}}
    {{compile.incremental}        {bool}   {0}                                     {Perform incremental compilation}}
    {{compile.unifast}            {bool}   {0}                                     {Enable fast simulation models}}
    {{compile.vlog_more_options}  {string} {}                                      {More VLOG options}}
    {{compile.vcom_more_options}  {string} {}                                      {More VCOM options}}
    {{simulate.custom_do}         {string} {}                                      {Specify name of the custom do file}}
    {{simulate.custom_udo}        {string} {}                                      {Specify name of the custom user do file}}
    {{simulate.sdf_delay}         {enum}   {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}} {Delay type}}
    {{simulate.saif}              {string} {}                                      {Specify SAIF file}}
    {{simulate.64bit}             {bool}   {0}                                     {Call 64bit VSIM compiler}}
    {{simulate.vsim_more_options} {string} {}                                      {More VSIM options}}
  }
  # create options
  ::tclapp::xilinx::modelsim::usf_create_options $simulator $options
  return 0
}
}
