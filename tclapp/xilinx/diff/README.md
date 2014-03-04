# Diff App


## Require the package:

    package require ::tclapp::xilinx::diff

## Pick Report Type (choose one):

### No Report - (stdout):

    set of [tclapp::xilinx::diff::new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp}]

### Report - HTML (example output):

    set report [tclapp::xilinx::diff::new_report "diff.html" "My Difference Report"]
    set of [tclapp::xilinx::diff::new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} $report]

### Report - Text (example output):

    set report [tclapp::xilinx::diff::new_report "diff.log" "My Difference Report"]
    set of [tclapp::xilinx::diff::new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} $report]

## Start Differencing:

    tclapp::xilinx::diff::diff_lists $of {get_cells -hierarchical} 
    tclapp::xilinx::diff::diff_reports $of {report_timing -return_string}
    tclapp::xilinx::diff::diff_props $of {get_timing_paths}
    ...

## Advanced:

    # import to the global namespace to make life easy
    namespace import ::tclapp::xilinx::diff::*

    # lists
    diff_lists $of {get_cells -hierarchical} 
    diff_lists $of {get_nets -hierarchical}
    diff_lists $of {get_clocks}
    diff_lists $of {get_ports}

    # lists vs reports
    diff_lists $of {get_property LOC [lsort [get_cells -hierarchical]]}
    diff_reports $of {join [get_property LOC [lsort [get_cells -hierarchical]]] \n}

    # reports
    diff_reports $of {report_timing -return_string -max_paths 1000} {timing}
    diff_reports $of {report_route_status -return_string -list_all_nets}
    diff_reports $of {report_route_status -return_string -of_objects [get_nets]}

    # properties
    diff_props $of {lrange [get_cells -hierarchical] 0 9999}
    diff_props $of {lrange [get_cells -hierarchical] 10000 19999}
    diff_props $of {get_timing_paths -max_paths 1000}

    # multi-line capable
    diff_lists $of {
      set paths [get_timing_paths -max_paths 1000]
      return [get_property SLACK [lsort $paths]]
    }

    diff_lists $of {
      set cells [get_cells -hierarchical]
      return [get_property LOC [lsort $cells]]
    } 

    diff_reports $of {
      set nets [get_nets]
      set subset_nets [lrange $nets 0 10]
      return [list [report_route_status -return_string -of_objects [get_nets $subset_nets]]]
    } 

    diff_props $of {
      set paths [get_timing_paths -max_paths 1000]
      return $paths
    }

## Closing Designs (not necessary)

    tclapp::xilinx::diff::diff_close_designs $of

## Variable Cleanup

    tclapp::xilinx::diff::delete $of

======

## Things to be aware of...

### Date Stamps

Date stamps will not be automatically handled. All tcl is allowed, so you can use replace algortihms to remove the date stamps before the comparison:

    tclapp::xilinx::diff::diff_reports $of { 
      set timing_results [report_timing -max_paths 100 -return_string]
      return [regsub -line {\| Date.*} $timing_results {}]
    }

### Using Variables

When necessary to reference a variable during diff object creation - do this as a normal Tcl string:

    set d1 "design1.dcp"
    set d2 "design2.dcp"
    set of [tclapp::xilinx::diff::new_diff "read_checkpoint $d1" "read_checkpoint $d2"]

### Different Project Runs

You can pass multiple commands to each of the load design commands, the design that will be used is the design that is active after all commands get executed:

    set of [tclapp::xilinx::diff::new_diff {open_project ./project_1/project_1.xpr; open_run synth_1} {open_project ./project_2/project_2.xpr; open_run synth_1}]

OR

    set of [tclapp::xilinx::diff::new_diff {
        open_project ./project_1/project_1.xpr
        open_run synth_1
      } {
        open_project ./project_2/project_2.xpr
        open_run synth_1
      }]

======

## Potential Improvements:


Add another layer of abstraction that doesn't require the use of an object variable

The use of current_design command will only work as is expected with in the first command

Add a method for regular text/variable differencing within the library

Add an automatic date stamp identifier and ignore switch

Add a debug switch

