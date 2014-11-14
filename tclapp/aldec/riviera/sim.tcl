######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common_sim 1.0
package require ::tclapp::aldec::common_helpers 1.0

namespace eval ::tclapp::aldec::riviera {

proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise
  
  return [eval ::tclapp::aldec::common_sim::setup $args]
}

proc compile { args } {
  # Summary: run the compile step for compiling the design files
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common_sim::compile $args]
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common_sim::elaborate $args]
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common_sim::simulate $args]
}
}
