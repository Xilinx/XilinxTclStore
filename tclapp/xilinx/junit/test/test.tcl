# run all junit smoke tests

set ::driverDir [ file normalize [ file dirname [ info script ] ] ]

# namespace eval is used here to contain per script variables
# a variable from one source would be available in another sourced script
# using different namespaces ensures correct variable references

namespace eval test0 {
  source [ file join $::driverDir project_step_high_ns run.tcl ]
}

namespace eval test1 {
  source [ file join $::driverDir project_step_high run.tcl ]
}

namespace eval test2 {
  source [ file join $::driverDir project_flow_low run.tcl ]
}

namespace eval test3 {
  source [ file join $::driverDir project_flow_inter run.tcl ]
}

namespace eval test4 {
  source [ file join $::driverDir project_flow_high run.tcl ]
}

namespace eval test5 {
  source [ file join $::driverDir project_hook_high run.tcl ]
}

puts "completed with all tests."

