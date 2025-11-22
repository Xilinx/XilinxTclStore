#########################################################################
#
# register_options.tcl
#
# Create simulation fileset properties with default values for the 
# 'Cadence Xcelium Parallel Simulator'
#
# Script created on 04/17/2017 by Raj Klair (Xilinx, Inc.)
#
# 2017.3 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xcelium {
  namespace export register_options
}

namespace eval ::tclapp::xilinx::xcelium {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-Xcelium-001 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-Xcelium-002 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::xcelium::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"]
  }

  set options {
    {{compile.tcl.pre}               {string} {}         {Specify pre-compile step TCL hook}}
    {{compile.v93}                   {bool}   {1}        {Enable VHDL93 features}}
    {{compile.relax}                 {bool}   {1}        {Enable relaxed VHDL interpretation}}
    {{compile.load_glbl}             {bool}   {1}        {Load GLBL module}}
    {{compile.xmvhdl.more_options}   {string} {}         {More XMVHDL compilation options}}
    {{compile.xmvlog.more_options}   {string} {}         {More XMVLOG compilation options}}
    {{compile.xmsc.more_options}     {string} {}         {More XMSC compilation options}}
    {{compile.g++.more_options}      {string} {}         {More G++ compilation options}}
    {{compile.gcc.more_options}      {string} {}         {More GCC compilation options}}
    {{elaborate.update}              {bool}   {0}        {Check if unit is up-to-date before writing}}
    {{elaborate.acc}                 {bool}   {1}        {Enable visibility access to simulation objects}}
    {{elaborate.link.sysc}           {string} {}         {Specify SystemC libraries to bind}}
    {{elaborate.link.c}              {string} {}         {Specify C/C++ libraries to bind}}
    {{elaborate.xmelab.more_options} {string} {}         {More XMELAB elaboration options}}
    {{simulate.tcl.post}             {string} {}         {Specify post-simulate step TCL hook}}
    {{simulate.runtime}              {string} {1000ns}   {Specify simulation run time}}
    {{simulate.log_all_signals}      {bool}   {0}        {Log all signals}}
    {{simulate.update}               {bool}   {0}        {Check if unit is up-to-date before writing}}
    {{simulate.ieee_warnings}        {bool}   {1}        {Suppress IEEE warnings}}
    {{simulate.saif_scope}           {string} {}         {Specify design hierarchy instance name for which power estimation is desired}}
    {{simulate.saif}                 {string} {}         {SAIF filename}}
    {{simulate.xmsim.more_options}   {string} {}         {More XMSIM simulation options}}
  }
  # create options
  ::tclapp::xilinx::xcelium::usf_create_options $simulator $options
  return 0
}
}
