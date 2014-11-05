#########################################################################
#
# register_options.tcl
#
#########################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::aldec::riviera {
  namespace export register_options
}


namespace eval ::tclapp::aldec::riviera {
proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-[getSimulatorName]-1 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-[getSimulatorName]-2 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  set options {
    {{compile.vhdl_syntax}         {enum}   {93 93 {93 2002 2008}}   {Specify VHDL standard}}
    {{compile.vlog_syntax}         {enum}   {v2k5 v2k5 {v95 v2k v2k5 sv2k5 sv2k9}}   {Specify Verilog standard}}
    {{compile.vhdl_relax}   {bool}   {0}                                     {Relax strict VHDL LRM requirements}}
    {{compile.verilog_strict}   {bool}   {0}                                     {Force strict Verilog LRM mode}}    
    {{compile.incremental}   {bool}   {0}                                     {Perform incremental compilation}}
    {{compile.reorder}           {bool}   {0}                                     {Enable automatic VHDL file ordering}}    
    {{compile.debug}         {bool}   {0}                                     {Generate debugging information}}
    {{compile.load_glbl}         {bool}   {0}                                     {Load GLBL module}}    
    {{compile.vlog.more_options}   {string} {}                                      {More Verilog compilation options}}
    {{compile.vcom.more_options}   {string} {}                                      {More VHDL compilation options}}

    {{elaborate.access}            {bool}   {0}                                     {Enable access to objects optimized by default}}
    {{elaborate.unifast}           {bool}   {0}                                     {Enable fast simulation models}}

    {{simulate.runtime}            {string} {1000ns}                                {Specify simulation run time}}
    {{simulate.log_all_signals}    {bool}   {0}                                     {Log all signals in simulation database}}
    {{simulate.debug}    {bool}   {0}                                     {Enable debugging features}}
    {{simulate.verilog_acceleration}    {bool}   {0}                                     {Enable verilog acceleration}}
    {{simulate.uut}                {string} {}                                      {Specify hierarchical path of unit under test instance}}
    {{simulate.saif}               {string} {}                                      {Generate SAIF file for power analysis}}
    {{simulate.asim.more_options}  {string} {}                                      {More simulation options}}
  }
  # create options
  ::tclapp::aldec::riviera::usf_create_options $simulator $options
  return 0
}
}
