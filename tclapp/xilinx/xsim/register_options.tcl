#########################################################################
#
# register_options.tcl (create simulation fileset properties with default
#                       values for the 'Vivado Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
#########################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xsim {
  namespace export register_options
}

namespace eval ::tclapp::xilinx::xsim {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable options
  if { {} == $simulator } {
    send_msg_id USF-XSim-001 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-XSim-002 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::xsim::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"]
  }

  set options {
    {{compile.tcl.pre}               {string}      {}                                                   {Specify pre-compile step TCL hook}}
    {{compile.xvhdl.nosort}          {bool}        {1}                                                  {Do not sort VHDL files}}
    {{compile.xvlog.nosort}          {bool}        {1}                                                  {Do not sort Verilog files}}
    {{compile.xvlog.relax}           {bool}        {1}                                                  {Relax strict HDL language checking rules}}
    {{compile.xvhdl.relax}           {bool}        {1}                                                  {Relax strict HDL language checking rules}}
    {{compile.xsc.more_options}      {string}      {}                                                   {More XSC compilation options}}
    {{compile.xvlog.more_options}    {string}      {}                                                   {More XVLOG compilation options}}
    {{compile.xvhdl.more_options}    {string}      {}                                                   {More XVHDL compilation options}}
    {{elaborate.snapshot}            {string}      {}                                                   {Specify name of the simulation snapshot}}
    {{elaborate.debug_level}         {enum}        {{typical} {typical} {{all} {typical} {off}}}        {Specify simulation debug visibility level. For visibility into Xilinx primitive use "all".}}
    {{elaborate.relax}               {bool}        {1}                                                  {Relax strict HDL language checking rules}}
    {{elaborate.mt_level}            {enum}        {{auto} {auto} {{auto} {off} {2} {4} {8} {16} {32}}} {Specify number of sub-compilation jobs to run in parallel}}
    {{elaborate.load_glbl}           {bool}        {1}                                                  {Load GLBL module}}
    {{elaborate.rangecheck}          {bool}        {0}                                                  {Enable runtime value range check for VHDL}}
    {{elaborate.sdf_delay}           {enum}        {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}}              {Specify SDF timing delay type to be read for use in timing simulation}}
    {{elaborate.xsc.more_options}    {string}      {}                                                   {More XSC elaboration options}}
    {{elaborate.xelab.more_options}  {string}      {}                                                   {More XELAB elaboration options}}
    {{simulate.tcl.post}             {string}      {}                                                   {Specify post-simulate step TCL hook}}
    {{simulate.runtime}              {string}      {1000ns}                                             {Specify simulation run time}}
    {{simulate.log_all_signals}      {bool}        {0}                                                  {Log all signals}}
    {{simulate.custom_tcl}           {string}      {}                                                   {Specify name of the custom TCL file}}
    {{simulate.wdb}                  {string}      {}                                                   {Specify waveform database file}}
    {{simulate.saif_scope}           {string}      {}                                                   {Specify design hierarchy instance name for which power estimation is desired}}
    {{simulate.saif}                 {string}      {}                                                   {SAIF filename}}
    {{simulate.saif_all_signals}     {bool}        {0}                                                  {Get all object signals for the design under test instance for SAIF file generation}}
    {{simulate.xsim.more_options}    {string}      {}                                                   {More XSIM simulation options}}
  }
  # create options
  ::tclapp::xilinx::xsim::usf_create_options $simulator $options
  return 0
}
}
