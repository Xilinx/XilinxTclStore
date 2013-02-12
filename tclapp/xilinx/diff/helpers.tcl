####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   09/13/12
# Script name:    helpers.tcl
# Procedures:     new_report, new_diff, diff_lists, diff_reports, diff_props, diff_close_designs
# Tool Versions:  Vivado 2012.3
# Description:    This script is used to compare 2 designs that have been loaded into memory.
# 
# Getting Started:
#     % source ./diff.tcl
#     % set report [new_report "diff.html" "Difference Report"]
#     % set of [new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} $report]
#     % diff_lists $of {get_cells -hierarchical} 
#     % diff_reports $of {report_timing -return_string}
#     % diff_props $of {get_timing_paths}
#     % diff_close_designs $of
#     % delete $of
#
####################################################################################################

# This file requires the stooop classes provided by classes.tcl 
package require ::tclapp::xilinx::diff::classes

# title: Vivado Design Differencing

namespace eval ::tclapp::xilinx::diff {
    # Export procs that should be allowed to import into other namespaces
    namespace export new_report 
    namespace export new_diff 
    namespace export diff_lists 
    namespace export diff_reports
    namespace export diff_props
    namespace export diff_close_designs 
    namespace export double_exec 
    namespace export delete
}

# section: Helper Procedures


proc ::tclapp::xilinx::diff::new_report {filename {title "Difference Report"}} {
	
    # Summary: 
    # This helper command is used to create a new report object.
    
    # Argument Usage: 
    # filename : This is the file name of the report. If the file name ends in .html, .html, or .xhtml then an HTML report will be generated. If the file name ends in anything else then a ASCII text report will be generated.
    # [title=Difference Report] : This specifies the title that will appear in the report.
    
    # Return Value:
    # report object - This object is used for writing to the report.
    
    # Examples:
    # new_report "report_name.html" "My Diff Report"
	
    set html_xtns {html htm xhtml}
    set fh [open $filename w+]
    fconfigure $fh -buffering line
    if { [regexp "\.([join $html_xtns |])" $filename] } {
        set report [stooop::new ::tclapp::xilinx::diff::html $fh]
    } else {
        set report [stooop::new ::tclapp::xilinx::diff::report $fh]
    }
    ::tclapp::xilinx::diff::report::start $report $title
    return $report
}


    
proc ::tclapp::xilinx::diff::new_diff {cmd_d1 cmd_d2 {report {}}} {
	
    # Summary:
    # This helper command is used to create a new diff object. 
    # This is the object that difference methods can be called on and differences can be reported.
    
    # Argument Usage: 
    # cmd_d1 : The new_diff helper expects 2 commands that will both open a design and make it the current design.  This is necessary because the project and design objects must both be captured for design switching (this is a current Vivado limitation, pending CR 668738).
    # cmd_2 :  This is the second command to open and make current a design.
    # [report=stdout] : report object  - The new_diff helper only needs a report object if you need a report file (returned from report_object).
    
    # Return Value:
    # diff object - This object is used for writing to the report.
    
    # Examples:
    #
    #    # printing results to stdout
    #    new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp}
    #
    #    # With a report file
    #    new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} [new_report diff.log]
	
    if { $report == {} } { set report [stooop::new ::tclapp::xilinx::diff::report stdout] }
    return [stooop::new ::tclapp::xilinx::diff::diff [stooop::new ::tclapp::xilinx::diff::design $cmd_d1 $report] [stooop::new ::tclapp::xilinx::diff::design $cmd_d2 $report] $report]
}



proc ::tclapp::xilinx::diff::diff_lists {this cmd} {
	
    # Summary:
    # This helper command is used to report the non-sequential differences between
    # the lists produced when executing a specific command on each design. In other words, if we ran 
    # get_cells on two designs and this is what was returned:
    #     design_1: a c d
    #     design_2: c d a 
    # Then diff_lists would say that the lists are equivalent. The diff_lists command *does not care 
    # about order*.
    
    # Argument Usage: 
    # this : An object created with new_diff, and the diff will compare the results from the designs set for the diff object and compare their results
    # cmd : The command that will be executed on each design and the results of this command will be compared between the two designs.
    
    # Return Value:
    # differences - The number of differences is returned.
    
    # Examples:
    # 
    #     # returns all of the difference cells
    #     diff_lists $from {get_cells -hierarchical} 
    # 
    #     # returns all of the different nets
    #     diff_lists $from {get_nets -hierarchical}
    # 
    #     # returns all of the different clocks
    #     diff_lists $from {get_clocks}
    # 
    #     # returns all of the different ports
    #     diff_lists $from {get_ports}
    # 
    #     # returns all of the different LOC properties (remember this compares
    #     # without regard to order, so this may not be an ideal comparison)
    #     diff_lists $from {get_property LOC [get_cells -hierarchical]}
    # 
    #     # returns slack differences for the first 1000 timing paths
    #     diff_lists $from {
    #         set paths [get_timing_paths -max_paths 1000]
    #         return [get_property SLACK [lsort $paths]]
    #     }
    
    return [::tclapp::xilinx::diff::diff::compare_lists $this $cmd]
}



proc ::tclapp::xilinx::diff::diff_reports {this cmd {unique_name {temp}}} {
	
    # Summary:
    # This helper command is used to report the sequential line differences between
    # the reports produced when executing a specific command on each design. In other words, if we ran 
    # report_clocks -return_string on two designs and this is what was returned:
    #     design_1:     design_2: 
    #         a             b
    #         b             c
    #         c             a
    # Then diff_reports would say that the reports have 2 differences. The diff_reports command *does 
    # care about order*.
    #    
    # Notice:
    # It is very important that the report_* commands are used with the '-return_string' 
    # switch, otherwise the results of the commands cannot be used. A check has been added for this and 
    # a warning will be issued.
    
    # Argument Usage: 
    # this : An object created with new_diff, and the diff will compare the results from the designs set for the diff object and compare their results
    # cmd  : A command that will be executed on each design and the results of this command will be compared between the two designs.
    # [unique_name=temp] : ???
    
    # Return Value:
    # differences - The number of differences is returned.
    
    # Examples:
    # 
    #     # returns the differences in the timing reports
    #     diff_reports $from {report_timing -return_string -max_paths 1000}
    # 
    #     # returns the differences in the nets from report_route_status
    #     diff_reports $from {report_route_status -return_string -list_all_nets}
    # 
    #     # returns the differences in the actual routes for nets
    #     diff_reports $from {report_route_status -return_string -of_objects [get_nets]}
    # 
    #     # returns the differences in the LOC properties (ordered)
    #     diff_reports $from {join [get_property LOC [lsort [get_cells -hierarchical]]] \n}
	
    return [::tclapp::xilinx::diff::diff::compare_reports $this $cmd $unique_name]
}



proc ::tclapp::xilinx::diff::diff_props {this cmd} {
	
    # Summary:
    # This helper command is used to report the sequential line differences between
    # all of the properties of the objects returned from a specific command on each design. In other 
    # words, if we ran report_properties -all [get_cells] on two designs and this is what was returned:
    #     design_1:     design_2: 
    #         a             a
    #           prop1: z      prop1: z
    #         b             b
    #           prop1: z      prop1: y
    #         c             c
    #           prop1: x      prop1: x
    # Then diff_reports would say that the reports have 1 difference. The diff_reports command *does 
    # care about order*.
    #
    # Notice:
    # Comparing properties can be a very demanding task, it is strongly recommended that this 
    # command be limited to 10000 objects at a time.
    
    # Argument Usage: 
    # this : An object created with new_diff, and the diff will compare the results from the designs set for the diff object and compare their results
    # cmd : The command that will be executed on each design and the results of this command will be compared between the two designs 
    
    # Return Value:
    # differences - The number of differences is returned.
    
    # Example:
    # 
    #     # returns all of the different cell properties for the first 10000
    #     diff_props $from {lrange [get_cells -hierarchical] 0 9999}
    # 
    #     # returns all of the different net properties for the second 10000
    #     diff_props $from {lrange [get_cells -hierarchical] 10000 19999}
    # 
    #     # returns all of the different clocks
    #     diff_props $from {get_timing_paths -max_paths 1000}
    # 
    #     # returns all of the different ports
    #     diff_props $from {
    #         set paths [get_timing_paths -max_paths 1000]
    #         return $paths
    #     }
	
    return [::tclapp::xilinx::diff::diff::compare_props $this $cmd]
}



proc ::tclapp::xilinx::diff::diff_close_designs {this} {
	
    # Summary:
    # This helper command is used to close the designs that are open and that were being compared.
    #
    # Notice:
    # This command will close the designs, but does not remove the objects - use delete to clean up 
    # objects.
    
    # Argument Usage: 
    # this : an object created with new_diff, and it contains the 2 designs which will be closed.
    
    # Return Value:
    # A list of the command returns
    
    # Example:
    # 
    #     # returns all of the different cell properties for the first 10000
    #     diff_props $from {lrange [get_cells -hierarchical] 0 9999}
    # 
    #     # returns all of the different net properties for the second 10000
    #     diff_props $from {lrange [get_cells -hierarchical] 10000 19999}
    # 
    #     # returns all of the different clocks
    #     diff_props $from {get_timing_paths -max_paths 1000}
    # 
    #     # returns all of the different ports
    #     diff_props $from {
    #         set paths [get_timing_paths -max_paths 1000]
    #         return $paths
    #     }
    
    # ::tclapp::xilinx::diff::double_exec {close_design}
	return [concat
    [::tclapp::xilinx::diff::design::execcmd $::tclapp::xilinx::diff::diff::($this,d1) {close_design}]
    [::tclapp::xilinx::diff::design::execcmd $::tclapp::xilinx::diff::diff::($this,d2) {close_design}]]
}



proc ::tclapp::xilinx::diff::double_exec {this cmd} {
	
    # Summary:
    # This helper command is used to execute any tcl command on both designs.
    
    # Argument Usage: 
    # this : An object created with new_diff, and it contains the 2 designs which will be closed.
    # cmd : Command to be executed on both designs
    
    # Return Value:
    # A list of the command returns
    
    # Example:
    # 
    #     # returns all of the different cell properties for the first 10000
    #     double_exec $from {route_design}
	
	return [concat
    [::tclapp::xilinx::diff::design::execcmd $::tclapp::xilinx::diff::diff::($this,d1) "$cmd"]
    [::tclapp::xilinx::diff::design::execcmd $::tclapp::xilinx::diff::diff::($this,d2) "$cmd"]]
}

proc ::tclapp::xilinx::diff::delete {this} {

    # Summary:
    # Wrapper around stooop::delete to delete stooop managed object

    # Return Value:
    # nothing

    # Argument Usage: 
    # this : An object created with new_diff that is to be deleted
    
    stooop::delete $this
}
