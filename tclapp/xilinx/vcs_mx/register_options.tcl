#########################################################################
#
# register_options.tcl (create simulation fileset properties with default
#                       values for the 'Synopsys VCS_MX Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 2013.1
package require ::tclapp::xilinx::vcs_mx::helpers

namespace eval ::tclapp::xilinx::vcs_mx {
proc register_options { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable options
  if { {} == $simulator } {
    send_msg_id Vivado-VCS_MX-999 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id Vivado-VCS_MX-999 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }
  # simulation fileset object on which the options will be created and value set
  set fs_obj [current_fileset -simset]
  set options {
    {{compile.32bit}          {bool}   {1}                                                   {Invoke 32-bit executable}}
    {{compile.load_glbl}      {bool}   {1}                                                   {Load GLBL module}}
    {{compile.more_options}   {string} {}                                                    {More Compilation Options}}
    {{elaborate.debug_pp}     {bool}   {1}                                                   {Enable post-process debug access}}
    {{elaborate.more_options} {string} {}                                                    {More Elaboration Options}}
    {{simulate.saif}          {string} {}                                                    {SAIF Filename}}
    {{simulate.more_options}  {string} {}                                                    {More Simulation Options}}
  }
  # create options
  ::tclapp::xilinx::vcs_mx::usf_create_options $simulator $options
  return 0
}
}
