######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common::sim 1.11
package require ::tclapp::aldec::common::helpers 1.11

namespace eval ::tclapp::aldec::activehdl {

proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  ::tclapp::aldec::common::helpers::usf_aldec_correctSetupArgs args

  return [eval ::tclapp::aldec::common::sim::setup $args]
}

proc compile { args } {
  # Summary: run the compile step for compiling the design files
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common::sim::compile $args]
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common::sim::elaborate $args]
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return [eval ::tclapp::aldec::common::sim::simulate $args]
}

proc export_simulation { args } {
  # Summary: export compilation and simulation scripts

  # Argument Usage:
  # -run_dir <arg>: Simulation run directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation

  # Return Value:

  # Categories: xilinxtclstore, aldec


  # check current simulator
  set currentSimulator [get_property target_simulator [current_project]]
  if { $currentSimulator != "ActiveHDL" } {
    set_property target_simulator "ActiveHDL" [current_project]
  } else {
    set currentSimulator ""
  }

  # export scripts
  set switches "-generate_scripts_only"

  for { set i 0 } { $i < [llength $args] } { incr i } {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-lib_map_path"   { incr i; append switches " -lib_map_path \{[lindex $args $i]\}" }
      "-run_dir"        { incr i; append switches " -run_dir \{[lindex $args $i]\}" }
      "-mode"        { incr i; append switches " -mode [lindex $args $i]" }
      "-type"        { incr i; append switches " -type [lindex $args $i]" }
    }
  }  

  setup "\{ $switches \}"
  compile
  elaborate
  simulate
  
  # restore previous simulator
  if { $currentSimulator != "" } {
    set_property target_simulator $currentSimulator [current_project]
  }
}

}
