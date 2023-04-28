#########################################################################
#
# register_options.tcl (create simulation fileset properties with default
#                       values for the 'ModelSim/Questa Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::modelsim {
  namespace export register_options
}


namespace eval ::tclapp::xilinx::modelsim {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-ModelSim-001 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-ModelSim-002 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::modelsim::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"]
  }

  set options {
    {{compile.tcl.pre}             {string} {}                                      {Specify pre-compile step TCL hook}}
    {{compile.vhdl_syntax}         {enum}   {{93} {93} {{93} {87} {2002} {2008}}}   {Specify VHDL syntax}}
    {{compile.use_explicit_decl}   {bool}   {1}                                     {Log all signals}}
    {{compile.load_glbl}           {bool}   {1}                                     {Load GLBL module}}
    {{compile.vlog.more_options}   {string} {}                                      {More VLOG compilation options}}
    {{compile.vcom.more_options}   {string} {}                                      {More VCOM compilation options}}
    {{elaborate.acc}               {bool}   {1}                                     {Enable access to simulation objects that might be optimized by default}}
    {{elaborate.vopt.more_options} {string} {}                                      {More VOPT elaboration options}}
    {{simulate.tcl.post}           {string} {}                                      {Specify post-simulate step TCL hook}}
    {{simulate.runtime}            {string} {1000ns}                                {Specify simulation run time}}
    {{simulate.log_all_signals}    {bool}   {0}                                     {Log all signals}}
    {{simulate.custom_do}          {string} {}                                      {Specify name of the custom do file}}
    {{simulate.custom_udo}         {string} {}                                      {Specify name of the custom user do file}}
    {{simulate.custom_wave_do}     {string} {}                                      {Specify name of the custom wave do file}}
    {{simulate.sdf_delay}          {enum}   {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}} {Delay type}}
    {{simulate.ieee_warnings}      {bool}   {1}                                     {Suppress IEEE warnings}}
    {{simulate.saif_scope}         {string} {}                                      {Specify design hierarchy instance name for which power estimation is desired}}
    {{simulate.saif}               {string} {}                                      {Specify SAIF file}}
    {{simulate.vsim.more_options}  {string} {}                                      {More VSIM simulation options}}
  }
  # create options
  ::tclapp::xilinx::modelsim::usf_create_options $simulator $options
  return 0
}
}
