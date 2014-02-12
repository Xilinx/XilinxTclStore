####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
#
# Date Created     :  01/01/2014
# Script name      :  register_options.tcl
# Tool Version     :  Vivado 2014.1
# Description      :  Setup "IES" simulator options on the simulation fileset
#
# Revision History :
#   01/01/2014 1.0  - Initial version
#
####################################################################################################
package require Vivado 2013.1
package require ::tclapp::xilinx::ies::helpers

namespace eval ::tclapp::xilinx::ies {
proc register_options { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable options
  if { {} == $simulator } {
    send_msg_id Vivado-IES-999 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id Vivado-IES-999 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }
  # simulation fileset object on which the options will be created and value set
  set fs_obj [current_fileset -simset]
  set options {
    {{compile.v93}            {bool}   {1}                                                   {Enable VHDL93 features}}
    {{compile.32bit}          {bool}   {1}                                                   {Invoke 32-bit executable}}
    {{compile.relax}          {bool}   {1}                                                   {Enable relaxed VHDL interpretation}}
    {{compile.unifast}        {bool}   {0}                                                   {Enable fast simulation models}}
    {{compile.load_glbl}      {bool}   {1}                                                   {Load GLBL module}}
    {{compile.more_options}   {string} {}                                                    {More Compilation Options}}
    {{elaborate.more_options} {string} {}                                                    {More Elaboration Options}}
    {{simulate.saif}          {string} {}                                                    {SAIF Filename}}
    {{simulate.more_options}  {string} {}                                                    {More Simulation Options}}
  }
  # create options
  ::tclapp::xilinx::ies::usf_create_options $simulator $options
  return 0
}
}
