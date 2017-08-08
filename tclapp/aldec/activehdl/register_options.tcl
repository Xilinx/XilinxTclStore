#########################################################################
#
# register_options.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\register_options.tcl
#
#########################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common::helpers 1.11

namespace eval ::tclapp::aldec::activehdl {

proc register_options { simulator } {
  # Summary: define simulation fileset options
  # Argument Usage:
  # simulator: name of the simulator for which the options needs to be defined
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable options
  if { {} == $simulator } {
    send_msg_id USF-[::tclapp::aldec::common::helpers::usf_getSimulatorName]-1 ERROR "Simulator not specified.\n"
  }
  # is simulator registered?
  if { {-1} == [lsearch [get_simulators] $simulator] } {
    send_msg_id USF-[::tclapp::aldec::common::helpers::usf_getSimulatorName]-2 ERROR "Simulator '$simulator' is not registered\n"
    return 1
  }

  set options {
    {{compile.tcl.pre}             {string} {}                        {Specify pre-compile step TCL hook}}
    {{compile.vhdl_syntax}         {enum}   {93 93 {93 2002 2008}}   {Specify VHDL standard}}
    {{compile.vlog_syntax}         {enum}   {2005 2005 {1995 2001 2005}}   {Specify Verilog standard}}
    {{compile.sv_syntax}         {enum}   {2012 2012 {2005 2009 2012}}   {Specify SystemVerilog standard}}
    {{compile.vhdl_relax}   {bool}   {0}                                     {Relax strict VHDL LRM requirements}}
    {{compile.incremental}   {bool}   {0}                                     {Perform incremental compilation}}
    {{compile.debug}         {bool}   {0}                                     {Generate debugging information}}
    {{compile.load_glbl}         {bool}   {0}                                     {Load GLBL module}}    
    {{compile.vlog.more_options}   {string} {}                                      {More Verilog compilation options}}
    {{compile.vcom.more_options}   {string} {}                                      {More VHDL compilation options}}

    {{compile.statement_coverage}         {bool}   {0}                        {Statement Coverage}}
    {{compile.branch_coverage}         {bool}   {0}                           {Branch Coverage}}
    {{compile.expression_coverage}         {bool}   {0}                       {Expression Coverage}}
    {{compile.condition_coverage}         {bool}   {0}                        {Condition Coverage}}
    {{compile.path_coverage}         {bool}   {0}                             {Path Coverage}}
    {{compile.assertion_coverage}         {bool}   {0}                        {Assertion Coverage}}
    {{compile.fsm_coverage}         {bool}   {0}                              {FSM Coverage}}
    {{compile.enable_expressions_on_subprogram_arguments} {bool} {0}              {Enable expressions on subprogram arguments}}
    {{compile.enable_atomic_expressions_in_the_conditional_statements} {bool} {0} {Enable atomic expressions in the conditional statements}}
    {{compile.enable_the_expressions_consisting_of_one_variable_only} {bool} {0}  {Enable the expressions consisting of one variable only}}
    {{compile.enable_the_expressions_with_relational_operators} {bool} {0}        {Enable the expressions with relational operators}}
    {{compile.enable_the_expressions_returning_vectors} {bool} {0}                {Enable the expressions returning vectors}}
    {{compile.enable_fsm_sequences_in_fsm_coverage} {bool} {0}                    {Enable FSM sequences in FSM Coverage}}

    {{elaborate.access}            {bool}   {0}                                     {Enable access to objects optimized by default}}
    {{elaborate.unifast}           {bool}   {0}                                     {Enable fast simulation models}}

    {{simulate.custom_do}          {string} {}                                      {Specify name of the custom DO file}}
    {{simulate.custom_udo}         {string} {}                                      {Specify name of the custom user DO file}}
    {{simulate.tcl.post}           {string} {}                                      {Specify post-simulate step TCL hook}}
    {{simulate.runtime}            {string} {1000ns}                                {Specify simulation run time}}
    {{simulate.log_all_signals}    {bool}   {0}                                     {Log all signals in simulation database}}
    {{simulate.debug}    {bool}   {0}                                     {Enable debugging features}}
    {{simulate.verilog_acceleration}    {bool}   {1}                                     {Enable verilog acceleration}}
    {{simulate.uut}                {string} {}                                      {Specify hierarchical path of unit under test instance}}
    {{simulate.saif}               {string} {}                                      {Generate SAIF file for power analysis}}
    {{simulate.asim.more_options}  {string} {}                                      {More simulation options}}

    {{simulate.statement_coverage}    {bool}   {0}                             {Statement Coverage}}
    {{simulate.branch_coverage}    {bool}   {0}                                {Branch Coverage}}
    {{simulate.functional_coverage}    {bool}   {0}                            {Functional Coverage}}
    {{simulate.expression_coverage}    {bool}   {0}                            {Expression Coverage}}
    {{simulate.condition_coverage}    {bool}   {0}                             {Condition Coverage}}
    {{simulate.path_coverage}    {bool}   {0}                                  {Path Coverage}}
    {{simulate.toggle_coverage}    {bool}   {0}                                {Toggle Coverage}}
    {{simulate.assertion_coverage}    {bool}   {0}                             {Assertion Coverage}}
    {{simulate.fsm_coverage}    {bool}   {0}                                   {FSM Coverage}}    
  }
  # create options
  ::tclapp::aldec::common::helpers::usf_create_options $simulator $options
  return 0
}
}
