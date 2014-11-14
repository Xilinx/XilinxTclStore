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

namespace eval ::tclapp::aldec::activehdl {

proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::aldec::common_helpers::usf_init_vars

  # read simulation command line args and set global variables
  ::tclapp::aldec::common_sim::usf_setup_args $args

  # perform initial simulation tasks
  if { [::tclapp::aldec::common_sim::usf_setup_simulation] } {
    return 1
  }
  return 0
}

proc compile { args } {
  # Summary: run the compile step for compiling the design files
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  set simulatorName [::tclapp::aldec::common_helpers::usf_getSimulatorName]

  send_msg_id USF-${simulatorName}-76 INFO "${simulatorName}::Compile design"
  if { [get_param project.writeNativeScriptForUnifiedSimulation] } {
    ::tclapp::aldec::common_sim::usf_write_compile_script_native
  } else {
    ::tclapp::aldec::common_sim::usf_write_compile_script
  }

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::common_helpers::usf_launch_script $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  set dir $::tclapp::aldec::common_helpers::a_sim_vars(s_launch_dir)
  
  set simulatorName [::tclapp::aldec::common_helpers::usf_getSimulatorName]

  send_msg_id USF-${simulatorName}-78 INFO "${simulatorName}::Simulate design"
  ::tclapp::aldec::common_sim::usf_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::common_helpers::usf_launch_script $step

  if { $::tclapp::aldec::common_helpers::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-${simulatorName}-79 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}
