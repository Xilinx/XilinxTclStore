#########################################################################
#
# register_options.tcl (create simulation fileset properties with default
#                       values for the 'Questa Advanced Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::questa {
  namespace export register_options
}


namespace eval ::tclapp::xilinx::questa {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-Questa-001 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-Questa-002 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::questa::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"]
  }

  set options {
    {{compile.tcl.pre}             {string} {}                                      {Type the file path with Tcl file name containing set of command hooks to run before the compilation starts}}
    {{compile.vhdl_syntax}         {enum}   {{93} {93} {{93} {87} {2002} {2008}}}   {Select the VHDL syntax standard}}
    {{compile.use_explicit_decl}   {bool}   {1}                                     {Select to log all signals}}
    {{compile.load_glbl}           {bool}   {1}                                     {Select to load GLBL module}}
    {{compile.sccom.cores}         {enum}   {{off} {off} {{off} {4} {8} {12} {16}}} {Specify the number of process cores to run in parallel}}
    {{compile.sccom.more_options}  {string} {}                                      {Specify more SCCOM compilation options. Separate the options with a space. See the sccom -help for additional options you want to set.}}
    {{compile.vlog.more_options}   {string} {}                                      {Specify more VLOG compilation options. Separate the options with a space. See the vlog -help for additional options you want to set.}}
    {{compile.vcom.more_options}   {string} {}                                      {Specify more VCOM compilation options. Separate the options with a space. See the vcom -help for additional options you want to set.}}
    {{elaborate.acc}               {enum}   {{acc=npr} {acc=npr} {{acc=npr} {acc} {None}}} {Select access to simulation objects that can be optimized by default (acc=npr: visibility into internal components for debugging or waveform analysis, acc: access the objects and internal signals, none: turns off this option)}}
    {{elaborate.link.sysc}         {string} {}                                      {Type the file path and the name of the SystemC library to bind}}
    {{elaborate.link.c}            {string} {}                                      {Type the file path and the name of the C/C++ library to bind}}
    {{elaborate.sccom.more_options} {string} {}                                     {Specify more options for sccom elaboration options. Separate the options with a space. See the sccom -help for additional options you want to set.}}
    {{elaborate.vopt.more_options} {string} {}                                      {Specify more VOPT elaboration options. Separate the options with a space. See the vopt -help for additional options you want to set.}}
    {{simulate.tcl.post}           {string} {}                                      {Type the file path with Tcl file name containing set of command hooks to run after the simulation ends}}
    {{simulate.runtime}            {string} {1000ns}                                {Specify simulation run time}}
    {{simulate.log_all_signals}    {bool}   {0}                                     {Select to log simulation output for viewing specified HDL objects}}
    {{simulate.custom_do}          {string} {}                                      {Type the file path and the name of the custom do file to source instead of default do file}}
    {{simulate.custom_udo}         {string} {}                                      {Type the file path and the name of the custom udo file to source instead of default udo file}}
    {{simulate.custom_wave_do}     {string} {}                                      {Type the file path and the name of the custom wave do file to source instead of default wave do file}}
    {{simulate.sdf_delay}          {enum}   {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}} {Select the delay type for sdf annotation}}
    {{simulate.ieee_warnings}      {bool}   {1}                                     {Select to suppress IEEE warnings}}
    {{simulate.saif_scope}         {string} {}                                      {Type the file path and the name of the design hierarchy instance name for which power estimation is needed}}
    {{simulate.saif}               {string} {}                                      {Type the file path and the name of the SAIF file. The SAIF file provides information about transitions in a digital circuit. This data helps with power estimation and optimization.}}
    {{simulate.sc_async_update}    {bool}   {0}                                     {Select to enable asynchronous request updates for SystemC}}
    {{simulate.vsim.more_options}  {string} {}                                      {Specify more VSIM simulation options. Separate the options with a space. See the vsim -help for additional options you want to set.}}
  }
  if {[get_param "simulator.enableqisflow"]} {
    append options {{{elaborate.opt_mode}  {enum}   {{access} {access} {{access} {debug}}}  {Select vopt execution mode (default:access)}}}
  }
  # create options
  ::tclapp::xilinx::questa::usf_create_options $simulator $options
  return 0
}
}
