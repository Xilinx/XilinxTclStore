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
    {{compile.tcl.pre}               {string}      {}                                                   {Type the file path with Tcl file name containing set of command hooks to run before the compilation starts}}
    {{compile.xvhdl.nosort}          {bool}        {1}                                                  {Select to disable VHDL compile order sorting}}
    {{compile.xvlog.nosort}          {bool}        {1}                                                  {Select to disable Verilog compile order sorting}}
    {{compile.xvlog.relax}           {bool}        {1}                                                  {Select to relax strict Verilog and SystemVerilog language checking rules}}
    {{compile.xvhdl.relax}           {bool}        {1}                                                  {Select to relax strict VHDL language checking rules}}
    {{compile.xsc.mt_level}          {enum}        {{auto} {auto} {{auto} {off} {2} {4} {8} {16} {32}}} {Select the number of sub-compilation jobs to run in parallel (auto: automatic, n: integer value greater than 1, off: turn off multi-threading)}}
    {{compile.xsc.more_options}      {string}      {}                                                   {Specify more XSC compilation options. Separate the options with a space. See the xsc -help for additional options you want to set.}}
    {{compile.xvlog.more_options}    {string}      {}                                                   {Specify more XVLOG compilation options. Separate the options with a space. See the xvlog -help for additional options you want to set.}}
    {{compile.xvhdl.more_options}    {string}      {}                                                   {Specify more XVHDL compilation options. Separate the options with a space. See the xvhdl -help for additional options you want to set.}}
    {{elaborate.snapshot}            {string}      {}                                                   {Type the file path and the name of the simulation snapshot}}
    {{elaborate.debug_level}         {enum}        {{typical} {typical} {{all} {typical} {off}}}        {Select simulation debug visibility level (all: use to gain visibility into AMD primitive, typical: uses settings that work for most elaborations, off: turns off this option)}}
    {{elaborate.relax}               {bool}        {1}                                                  {Select to relax strict HDL language checking rules}}
    {{elaborate.mt_level}            {enum}        {{auto} {auto} {{auto} {off} {2} {4} {8} {16} {32}}} {Specify number of sub-compilation jobs to run in parallel (auto: automatic, n: integer value greater than 1, off: turn off multi-threading)}}
    {{elaborate.load_glbl}           {bool}        {1}                                                  {Select to load GLBL module}}
    {{elaborate.rangecheck}          {bool}        {0}                                                  {Select to enable a runtime value range check for VHDL}}
    {{elaborate.sdf_delay}           {enum}        {{sdfmax} {sdfmax} {{sdfmin} {sdfmax}}}              {Select SDF timing delay type to be read to use in timing simulation}}
    {{elaborate.link.sysc}           {string}      {}                                                   {Type the file path and the name of the SystemC library to bind. Separate multiple libraries with a space.}}
    {{elaborate.link.c}              {string}      {}                                                   {Type the file path and the name of the C/C++ library to bind. Separate multiple libraries with a space.}}
    {{elaborate.xsc.more_options}    {string}      {}                                                   {Specify more options for XSC during elaboration. Separate the options with a space. See the xsc -help for additional options you want to set.}}
    {{elaborate.xelab.more_options}  {string}      {}                                                   {Specify more XELAB elaboration options. Separate the options with a space. See the xelab -help for additional options you want to set.}}
    {{elaborate.coverage.name}       {string}      {}                                                   {Type the name of the coverage database}}
    {{elaborate.coverage.dir}        {string}      {}                                                   {Type the file path of the coverage directory}}
    {{elaborate.coverage.type}       {string}      {}                                                   {Specify coverage type(s) (Statement (or s) Branch (or b) Condition (or c) Toggle (or t) or All (or sbct))}}
    {{elaborate.coverage.library}    {bool}        {0}                                                  {Select to track std/unisims/retarget libraries}}
    {{elaborate.coverage.celldefine} {bool}        {0}                                                  {Select to track modules with celldefine attributes}}
    {{simulate.tcl.post}             {string}      {}                                                   {Type the file path with Tcl file name containing set of command hooks to run after the simulation ends}}
    {{simulate.runtime}              {string}      {1000ns}                                             {Specify the simulation run time}}
    {{simulate.log_all_signals}      {bool}        {0}                                                  {Select to log simulation output for viewing specified HDL objects}}
    {{simulate.no_quit}              {bool}        {0}                                                  {Select to disable simulation quit (applicable for -scripts_only mode)}}
    {{simulate.custom_tcl}           {string}      {}                                                   {Type the file path and the name of the custom TCL file to source instead of default TCL file}}
    {{simulate.wdb}                  {string}      {}                                                   {Type the file path and the name of the simulation waveform database output file}}
    {{simulate.saif_scope}           {string}      {}                                                   {Type the file path and the name of the design hierarchy instance name for which power estimation is needed}}
    {{simulate.saif}                 {string}      {}                                                   {Type the file path and the name of the SAIF file. The SAIF file provides information about transitions in a digital circuit. This data helps with power estimation and optimization.}}
    {{simulate.saif_all_signals}     {bool}        {0}                                                  {Select to log all object signals for the design under test for SAIF file generation}}
    {{simulate.add_positional}       {bool}        {0}                                                  {Select to add positional parameter to the simulator for passing command line arguments ($* for Linux, %* for Windows)}}
    {{simulate.xsim.more_options}    {string}      {}                                                   {Specify more simulator options. Separate the options with a space. See the xsim -help for additional options you want to set.}}
  }
  # create options
  ::tclapp::xilinx::xsim::usf_create_options $simulator $options
  return 0
}
}
