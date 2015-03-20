#########################################################################
#
# register_options.tcl (create simulation fileset properties with default
#                       values for the 'Synopsys VCS Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::vcs {
  namespace export register_options
}

namespace eval ::tclapp::xilinx::vcs {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-VCS-001 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-VCS-002 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }
  set options {
    {{compile.load_glbl}            {bool}   {1}       {Load GLBL module}}
    {{compile.vhdlan.more_options}  {string} {}        {More VHDLAN compilation options}}
    {{compile.vlogan.more_options}  {string} {}        {More VLOGAN compilation options}}
    {{elaborate.debug_pp}           {bool}   {1}       {Enable post-process debug access}}
    {{elaborate.vcs.more_options}   {string} {}        {More VCS elaboration options}}
    {{simulate.runtime}             {string} {1000ns}  {Specify simulation run time}}
    {{simulate.uut}                 {string} {}        {Specify instance name for design under test (default:/uut)}}
    {{simulate.saif}                {string} {}        {SAIF filename}}
    {{simulate.vcs.more_options}    {string} {}        {More VCS simulation options}}
  }
  # create options
  ::tclapp::xilinx::vcs::usf_create_options $simulator $options
  return 0
}
}
