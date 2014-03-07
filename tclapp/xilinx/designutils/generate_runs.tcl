package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export generate_runs
}


proc ::tclapp::xilinx::designutils::generate_runs {perform_phys_opt} {
  # Summary : Create all possible combinations of runs

  # Argument Usage:
  # perform_phys_opt : 0 - do not perform phys_opt_design | 1 - perform phys_opt_design

  # Return Value:
  # Returns nothing, creates all possible combinations of runs in your session

  # Categories: xilinxtclstore, designutils



  set synth_flow {Vivado Synthesis 2013}
  set impl_flow {Vivado Implementation 2013}


#  proc getFlow {type} {
#     if {$type=="synth"} {
#        set vv [version -short]
#        regexp {^([0-9]+)} $vv year
#        set flow "Vivado Synthesis ${year}"
#        return $flow
#     } elseif { $type=="impl" } {
#        set vv [version -short]
#        regexp {^([0-9]+)} $vv year
#        set flow "Vivado Implementation ${year}"
#        return $flow
#     } else {
#        puts "ERROR: Not a supported flow type"
#        return "";
#     }
#  }

  proc getFlow {type} {
     if {$type=="synth"} {
        set flow [get_property flow [get_runs synth_dummy]]
        return $flow
     } elseif { $type=="impl" } {
        set flow [get_property flow [get_runs impl_dummy]]
        return $flow
     } else {
        puts "ERROR: Not a supported flow type"
        return "";
     }
  }






  proc create_dummy_runs {} {
     create_run -flow {Vivado Synthesis 2013} synth_dummy
     create_run -flow {Vivado Implementation 2013} -parent_run synth_dummy impl_dummy
     current_run [get_run synth_dummy]
     foreach run [get_runs -filter {NAME!~*dummy&&IS_SYNTHESIS}] {
        delete_run [get_run $run]
     }
  }

  proc delete_dummy_runs {} {
     foreach run [get_runs -filter {NAME=~*dummy&&IS_SYNTHESIS}] {
        delete_run [get_run $run]
      }
  }




  puts "Very Important Critical Warning: This script is not a patch for poor RTL coding and/or poor XDC constraints"


  create_dummy_runs

  set synth_directives [list_property_value STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE [get_runs synth_dummy]]

  set place_directives [list_property_value STEPS.PLACE_DESIGN.ARGS.DIRECTIVE [get_runs impl_dummy]]
  set place_directives [lsearch -all -inline -not -exact $place_directives Quick]

  set phys_opt_directives [list_property_value STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE [get_runs impl_dummy]]

  set route_directives [list_property_value STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE [get_runs impl_dummy]]
  set route_directives [lsearch -all -inline -not -exact $route_directives Quick]


  foreach synth $synth_directives {
	  set run_name "synth_${synth}"
          create_run $run_name -flow [getFlow synth]
	  puts "Created Synthesis run: $run_name"
  }

  foreach synth_run [get_runs -filter {NAME!~*dummy&&IS_SYNTHESIS} ] {
     puts "Creating Child Implementation Runs for Synthesis Run: $synth_run"
     foreach place $place_directives {
        if { $perform_phys_opt } {
           foreach phys_opt $phys_opt_directives {
              foreach route $route_directives {
               set run_name "${synth_run}.${place}.${phys_opt}.${route}"
               create_run $run_name -parent_run $synth_run -flow [getFlow impl]
               puts "\tCreated Child Implementation Run: $run_name"
              }
           }
        } else {
           foreach route $route_directives {
            set run_name "${synth_run}.${place}.${route}"
            create_run $run_name -parent_run $synth_run -flow [getFlow impl]
            puts "\tCreated Child Implementation Run: $run_name"
           }
        }
     }
  }

  delete_dummy_runs



}
