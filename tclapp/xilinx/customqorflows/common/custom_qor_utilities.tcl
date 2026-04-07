####################################################################################
#
# custom_qor_utilities.tcl (customqorflows common utilities)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc build_data_from_report_table {report_string table_name {indexing_master ""}} {
		# Summary:
		# Parses report table strings and extracts data into a hierarchical dictionary structure.
		#
		# Argument Usage:
		# report_string - The multi-line report text containing table(s) to parse
		# table_name - The name identifier of table to extract (regexp match)
		# indexing_master - Optional column name to use as primary key (default: "" uses first column)
		#
		# Return Value:
		# Dictionary with structure {index_value {column_name value ...} ...} or empty dict if table not found
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# The proc checks for the following
		# i)    Identifies a table name based on the $table name property
		# ii)   Expects the table header to be underlined on the next lines ----
		# iii)  Expects 0 or more lines in between underline line and the table
		# iv)   Expects table separator lines to be formatted: +---+
		# v)    Expects a single header line
		# vi)   Expects a table separator lines to be formatted: +---+
		# vii)  Expects lines of data after this
		# viii) Expects a table separator lines to be formatted: +---+
		# ix)   Expects a line that does not start with a table + or | to indicate the end of the table.
		set debug 0
		set return_dict [dict create]
		set updated_indexing_master [string map {" " ""} $indexing_master]
		if {$debug ==1} {puts "-D: Table name $table_name"}
		set lines [split $report_string \n]
		for {set i 0} {$i < [llength $lines]} {incr i} {
			set line [lindex $lines $i]
			if {[regexp "${table_name}" $line]} {
				set line_length [string length $line]
				set table_header_line $line
				incr i
				set line [lindex $lines $i]
				if {$line eq [string repeat - $line_length]} {
					if {$debug ==1} {puts "-D: found a table header"}
					incr i
					set line [lindex $lines $i]
					while {[regexp {^\s*$} $line]} {
						if {$debug ==1} {puts "-D: Found a white space line"}
						incr i
						set line [lindex $lines $i]
					}
					if {[regexp {\s*\+\-*.*} $line separator_line]} {
						if {$debug ==1} {puts "-D: Found a separator line: $separator_line"}
						incr i
						set line [lindex $lines $i]
						set headings [split [string range $line 2 end-2] |]
						if {$debug ==1} {puts "-D: Headings are $headings"}
						foreach heading $headings {
							set header [string map {" " ""} $heading]
							lappend headings_updated $header
						}
						if {$debug ==1} {puts "-D: Updated Headings are: $headings_updated"}
						if {$debug ==1} {puts "-D: updated_indexing_master: $updated_indexing_master"}
						if {$updated_indexing_master eq ""} {
							set idx 0
						} elseif {[set idx [lsearch -exact $headings_updated $updated_indexing_master]] == -1} {
							puts "-E: Incorrect heading index master specified in build_data_from_report_table"
							return						
						}
						set headings_updated [::tclapp::xilinx::customqorflows::lremove_sgl $headings_updated $idx]
						if {$debug ==1} {puts "-D: Updated Headings are: $headings_updated"}
						incr i
						set line [lindex $lines $i]
						if {$line ne $separator_line} {
							if {$debug ==1} {puts "-D: separator: $separator_line line: $line" }
							puts "-E: The table has a two line header. Not supported"
							return
						}
						incr i
						set line [lindex $lines $i]
						while {$line ne $separator_line && [regexp {^\s*$} $line]==0 } {
							set data [split [string range $line 2 end-2] |]
							# set data [string map {" " ""} $data]
							set idx_dataline [::tclapp::xilinx::customqorflows::trim_space [lindex $data $idx]]
							set tmp [dict create]
							set dataline [::tclapp::xilinx::customqorflows::lremove_sgl $data $idx]
							if {$debug ==1} {puts "-D: idx_dataline: $idx_dataline $data $idx"}
							for {set j 0} {$j < [llength $headings_updated]} {incr j} {
								if {$debug ==1} {puts "-D: INDEX: [lindex $headings_updated $j] VALUE: [lindex $dataline $j]"}
								dict set tmp [lindex $headings_updated $j] [::tclapp::xilinx::customqorflows::trim_space [lindex $dataline $j]]
							}
							dict set return_dict $idx_dataline $tmp
							if {$debug ==1} {puts "-D: Dict : [dict get $tmp]"}
							unset tmp
							incr i
							set line [lindex $lines $i]						
						}
					}
				}		
			}	
		}
		# puts [dict get $return_dict]
		return $return_dict
	}


	proc compile_time {start stop {command ""} {unique_string "RQS USER:"} {print_st_fid ""}} {
		# Summary:
		# Formats and displays elapsed execution time between two timestamps in HH:MM:SS format.
		#
		# Argument Usage:
		# start - Start timestamp (output of [clock seconds])
		# stop - Stop timestamp (output of [clock seconds])
		# command - Optional command name for label (default: "" extracts caller proc name from [info level -1])
		# unique_string - Optional prefix string for output (default: "RQS USER:")
		# print_st_fid - Optional file handle to write output to (default: "" means no file output)
		#
		# Return Value:
		# Formatted string containing elapsed time in format: "<unique_string> <command> : elapsed = HH:MM:SS"
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Start and stop variable should be generated using [clock seconds]
		# This should return the proc level one above if no command is specified
		if {$command eq ""} {set command [lindex [info level -1] 0]}
		set time [expr $stop - $start]
		set mins [expr $time / 60]
		set hours [expr $mins / 60]
		set remainder_mins [expr $mins % 60]
		set remainder_secs [expr $time % 60]
		set str "$unique_string $command : elapsed = [format %02u ${hours}]:[format %02u $remainder_mins]:[format %02u $remainder_secs]"
		if {$print_st_fid ne ""} {puts $print_st_fid "$str"}
		return $str
	}

	proc pretty_command_property {property_name property_value target_objects {classtype ""} {quiet 1}} {
		# Summary:
		# Generates a formatted Vivado TCL command string for setting properties on multiple objects.
		#
		# Argument Usage:
		# property_name - Name of the property to set (string)
		# property_value - Value to assign to the property
		# target_objects - List of Vivado objects (cells, nets, or pins)
		# classtype - Optional object class type (default: "" auto-detects; must be cell/net/pin)
		# quiet - 1 to add -quiet flag to generated command (default: 1)
		#
		# Return Value:
		# Formatted TCL command string for set_property; or returns error code 2 with formatted error message on validation failure
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# DRC
		# 1) CLASS check
		if {$classtype eq ""} {
			set classtype [lsort -unique [get_property -quiet CLASS $target_objects]]
		}
		if {[llength $classtype] != 1 || $classtype eq ""} { 
			puts "RQS_ERROR: Failed during creation of command property. Target objects are not all of one class."; 
			return -code 2 "Error: Invalid class value on objects in command generation"
		}
		# 2) CLASS value
		if {$classtype ne "cell" && $classtype ne "net" && $classtype ne "pin"} {
			puts "RQS_ERROR: Only objects with class of cell, net and pin are supported. Class $classtype is not supported"; 
			return -code 2 "Error: Only objects with class of cell, net and pin are supported. Class $classtype is not supported"
		}
		# 3) Number of target objects > 0
		if {[llength $target_objects] == 0} { 
			puts "RQS_ERROR: Zero objects being targeted in COMMAND property generation"; 
			return -code 2 "Error: Zero objects being targeted in COMMAND property generation"
		}
		
		if {[llength $target_objects] > 1} {
			set rt "set_property $property_name $property_value \[get_${classtype}s "
			if {$quiet == 1} {set rt "${rt} -quiet "}
			if {[llength $target_objects] > 1} {
				set rt "${rt}\{"
			}
			set formatted_object_names ""
			for {set i 0} {$i < [llength $target_objects]-1} {incr i} {
				set target_object [lindex $target_objects $i]
				set formatted_object_names [concat $formatted_object_names \{$target_object\} \\\n]				
			}
			set target_object [lindex $target_objects end]
			set formatted_object_names [concat $formatted_object_names \{$target_object\}]			
			set rt "${rt} $formatted_object_names  \} \]"
		} else {
			set rt "set_property $property_name $property_value \[get_${classtype}s \{ $target_objects \} \]"
		}
		return $rt	
	}
	
	proc pretty_partial_command {target_objects} {
		# Summary:
		# Formats a list of Vivado objects into a TCL-compliant command object list with line breaks for readability.
		#
		# Argument Usage:
		# target_objects - List of Vivado objects (any class type supported)
		#
		# Return Value:
		# Formatted string in TCL list syntax: {object1 \ object2 \n object3 ...} with multi-line formatting for readability
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# This proc requires more work for the user to use than the above one.
		# However it will work on any object list unlike the above.
		# input cell1 cell2
		# output {{cell1}\
		#        {cell2} }
		if {[llength $target_objects] > 1} {
			set formatted_object_names ""
			foreach target_object $target_objects {
				set formatted_object_names [concat $formatted_object_names \{$target_object\} \\\n]
			}	
			if {[llength $target_objects] > 1} {
				set rt "\{"
			}
			set rt "${rt} $formatted_object_names"
			if {[llength $target_objects] > 1} {
				set rt "$rt \}"
			}
		} else {
			set rt "\{ ${target_objects} \}"
		}	
	}
	

	proc sort_by_property {list_to_sort property_name {sort_type "ascending"}} {
		# Summary:
		# Sorts a list of Vivado objects by an integer property value using lsort for performance.
		#
		# Argument Usage:
		# list_to_sort - List of Vivado objects (cells, nets, pins, etc.)
		# property_name - Name of the integer property to sort by
		# sort_type - Sort order: "ascending" or "descending" (default: "ascending")
		#
		# Return Value:
		# Sorted list of objects in specified order based on property value
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Sorts a list based on a property value. Property value must be an integer.
		# Ths has the benefit of sorting a list of objects using lsort instead of foreach.
		# This results in a speed up of script compile time.
		set debug 0
		set start [clock seconds]
		set values [get_property $property_name $list_to_sort]
		for {set i 0} {$i < [llength $list_to_sort]} {incr i} {
			lappend list_with_sorting_factors [list [lindex $values $i] [lindex $list_to_sort $i]]
		}
		if {$sort_type eq "ascending"} {
			set sorted_list [lsort -increasing -integer -index 0 $list_with_sorting_factors]
		} else {
			set sorted_list [lsort -decreasing -integer -index 0 $list_with_sorting_factors]	
		}
		foreach obj $sorted_list {
			lappend ret_list [lindex $obj 1]
		}

		set stop [clock seconds]
		if {$debug == 1} {puts "-D: Sorting took [expr $stop - $start] seconds"}
		return $ret_list
	}

	proc update_params {params qor_dict} {
		# Summary:
		# Updates local parameter array from a qor_dict configuration dictionary (PARAMS key).
		#
		# Argument Usage:
		# params - Variable name of parameter array to update (passed by name via upvar)
		# qor_dict - Configuration dictionary with optional PARAMS key containing parameter overrides
		#
		# Return Value:
		# No explicit return; modifies caller's PARAMS array via upvar (side effect)
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# this proc is to update params that can be used add configurability to custom qor suggestions
		upvar $params PARAMS		
		set debug 0		
		if {$qor_dict ne ""} {
			if {$debug == 1} {puts "-D: Found a dictionary"}
			if {[llength [dict key $qor_dict PARAMS]] != 0} {
			set param_dict [dict get $qor_dict PARAMS]
				foreach key [dict keys $param_dict] {
					puts "-I: Updating params $key to value [dict get $param_dict $key]"
					set PARAMS($key) [dict get $param_dict $key]
				}
			}
		} else {
			if {$debug == 1} {puts "-D: Not found a dictionary"}
		}		
	}
	
}