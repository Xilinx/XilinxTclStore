####################################################################################
#
# tcl_utilities.tcl (customqorflows Tcl helper utilities)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
    
}

namespace eval ::tclapp::xilinx::customqorflows {

    # Procedure to convert array to dictionary
    proc array_to_dict {array_name} {
        # Summary:
        # Convert a Tcl array to a Tcl dict.
        #
        # Argument Usage:
        # array_name
        #
        # Return Value:
        # Dictionary created from array contents (empty dict when array does not exist).
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Converts a TCL array to a dictionary
        #
        # Arguments:
        # array_name - The name of the array variable to convert
        #
        # Returns:
        # Dictionary representation of the array

        upvar $array_name arr
        
        if {![array exists arr]} {
            puts "ERROR: Array $array_name does not exist"
            return [dict create]
        }
        
        set result_dict [dict create]
        foreach {key value} [array get arr] {
            dict set result_dict $key $value
        }
        
        return $result_dict
    }

    # Procedure to append to an existing array file
    proc append_array_to_file {array_name filename} {
        # Summary:
        # Append Tcl array content to a file in readable format.
        #
        # Argument Usage:
        # array_name filename
        #
        # Return Value:
        # Integer status code: 0 on success, 1 on failure.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Appends array entries to an existing array file
        # If file doesn't exist, creates a new one
        # New entries override existing ones with the same key
        #
        # Arguments:
        # array_name - The name of the array variable to append
        # filename   - The target filename
        #
        # Returns:
        # 0 on success, 1 on error

        upvar $array_name arr
        set debug 1
        
        if {![array exists arr]} {
            puts "ERROR: Array $array_name does not exist"
            return 1
        }
        
        if {$debug} {
            puts "-D: Appending array '$array_name' to file: $filename"
        }
        
        # Read existing array if file exists
        if {[file exists $filename]} {
            set result [read_array_from_file $filename "existing_array"]
            if {$result == -1} {
                puts "WARNING: Could not read existing array, creating new file"
                array unset existing_array
            }
        } else {
            array unset existing_array
        }
        
        # Merge arrays (new entries override existing ones)
        if {[array exists existing_array]} {
            array set existing_array [array get arr]
            set original_count [expr [array size existing_array] - [array size arr]]
        } else {
            array set existing_array [array get arr]
            set original_count 0
        }
        
        if {$debug} {
            puts "-D: Original entries: $original_count"
            puts "-D: New entries: [array size arr]"
            puts "-D: Merged entries: [array size existing_array]"
        }
        
        # Write the merged array
        return [write_array_to_file "existing_array" $filename "readable"]
    }

    # Procedure to append to an existing dictionary file
    proc append_dict_to_file {dict_var filename} {
        # Summary:
        # Append Tcl dict content to a file in readable format.
        #
        # Argument Usage:
        # dict_var filename
        #
        # Return Value:
        # Integer status code: 0 on success, 1 on failure.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Appends dictionary entries to an existing dictionary file
        # If file doesn't exist, creates a new one
        #
        # Arguments:
        # dict_var  - The dictionary variable to append
        # filename  - The target filename
        #
        # Returns:
        # 0 on success, 1 on error

        set debug 1
        
        if {$debug} {
            puts "-D: Appending dictionary to file: $filename"
        }
        
        # Read existing dictionary if file exists
        if {[file exists $filename]} {
            set existing_dict [read_dict_from_file $filename]
            if {[dict size $existing_dict] == 0} {
                puts "WARNING: Could not read existing dictionary, creating new file"
                set existing_dict [dict create]
            }
        } else {
            set existing_dict [dict create]
        }
        
        # Merge dictionaries (new entries override existing ones)
        set merged_dict [dict merge $existing_dict $dict_var]
        
        if {$debug} {
            puts "-D: Original entries: [dict size $existing_dict]"
            puts "-D: New entries: [dict size $dict_var]"
            puts "-D: Merged entries: [dict size $merged_dict]"
        }
        
        # Write the merged dictionary
        return [write_dict_to_file $merged_dict $filename "readable"]
    }

	proc compare_ascending {a b} {
		# Summary:
		# Comparator helper for ascending sort, with numeric-first comparison behavior.
		#
		# Argument Usage:
		# a b
		#
		# Return Value:
		# Comparator integer suitable for lsort -command (negative/zero/positive).
		#
		# Categories: xilinxtclstore, customqorflows
		#
		set a0 [lindex $a 0]
		set b0 [lindex $b 0]
		if {$a0 < $b0} {
			return -1
		} elseif {$a0 > $b0} {
			return 1
		}
		return [string compare [lindex $a 1] [lindex $b 1]]
	}

	proc compare_descending {a b} {
		# Summary:
		# Comparator helper for descending sort, with numeric-first comparison behavior.
		#
		# Argument Usage:
		# a b
		#
		# Return Value:
		# Comparator integer suitable for lsort -command (negative/zero/positive).
		#
		# Categories: xilinxtclstore, customqorflows
		#
		set a0 [lindex $a 0]
		set b0 [lindex $b 0]
		if {$a0 < $b0} {
			return 1
		} elseif {$a0 > $b0} {
			return -1
		}
		return [string compare [lindex $a 1] [lindex $b 1]]
	}

    proc dict_exists_check {mydict key} {
        # Summary:
        # Safely fetch dictionary value for key, returning empty string when key is missing.
        #
        # Argument Usage:
        # mydict key
        #
        # Return Value:
        # Dictionary value for key when present; empty string when key is missing.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        if {[dict exists $mydict $key]} {
            return [dict get $mydict $key]
        } else {
            return ""
        }
    }

    # Procedure to convert dictionary to array
    proc dict_to_array {dict_var array_name} {
        # Summary:
        # Populate array from dictionary key/value entries.
        #
        # Argument Usage:
        # dict_var array_name
        #
        # Return Value:
        # Integer count of array entries after conversion.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Converts a dictionary to a TCL array
        #
        # Arguments:
        # dict_var   - The dictionary to convert
        # array_name - The name of the array variable to create
        #
        # Returns:
        # Number of elements created

        upvar $array_name arr
        
        # Clear existing array
        if {[array exists arr]} {
            array unset arr
        }
        
        dict for {key value} $dict_var {
            set arr($key) $value
        }
        
        return [array size arr]
    }

	proc lremove_sgl {mylist index} {
		# Summary:
		# Remove one element at a given index from list and return updated list.
		#
		# Argument Usage:
		# mylist index
		#
		# Return Value:
		# Updated list with one element removed.
		#
		# Categories: xilinxtclstore, customqorflows
		#
		if {$index == 0} {
			set mylist [lrange $mylist 1 end]
		} elseif {$index == [llength $mylist]} {
			set mylist [lrange $mylist 0 end-1]
		} else {
			set mylist [concat [lrange $mylist 0 ${index}-1] [lrange $mylist ${index}+1 end]]
		}
		return $mylist
	}

    # Procedure to pretty print an array
    proc print_array {array_name {sort_keys 1}} {
        # Summary:
        # Print array content to stdout in a readable layout.
        #
        # Argument Usage:
        # array_name {sort_keys 1}
        #
        # Return Value:
        # No explicit return. Prints array content to stdout.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Pretty prints an array with optional key sorting
        #
        # Arguments:
        # array_name - The name of the array variable to print
        # sort_keys  - Whether to sort keys alphabetically (1) or not (0)

        upvar $array_name arr
        
        if {![array exists arr]} {
            puts "ERROR: Array $array_name does not exist"
            return
        }
        
        set count [array size arr]
        puts "Array '$array_name' ($count entries):"
        puts "=================================="
        
        if {$count == 0} {
            puts "  (empty array)"
            return
        }
        
        if {$sort_keys} {
            set keys [lsort [array names arr]]
        } else {
            set keys [array names arr]
        }
        
        foreach key $keys {
            set value $arr($key)
            # Handle multi-line values
            if {[string first "\n" $value] != -1} {
                puts "  $key:"
                foreach line [split $value "\n"] {
                    puts "    $line"
                }
            } else {
                puts "  $key = $value"
            }
        }
    }

    # Procedure to pretty print a dictionary
    proc print_dict {dict_var {indent 0}} {
        # Summary:
        # Recursively print dictionary content to stdout with indentation.
        #
        # Argument Usage:
        # dict_var {indent 0}
        #
        # Return Value:
        # No explicit return. Prints dictionary content to stdout.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Pretty prints a dictionary with proper indentation
        #
        # Arguments:
        # dict_var  - The dictionary to print
        # indent    - Current indentation level (for recursive calls)

        set spaces [string repeat "  " $indent]
        
        dict for {key value} $dict_var {
            if {[catch {dict size $value}] == 0 && [dict size $value] > 0} {
                # Value is a nested dictionary
                puts "${spaces}$key:"
                print_dict $value [expr $indent + 1]
            } elseif {[llength $value] > 1} {
                # Value is a list
                puts "${spaces}$key: \[list with [llength $value] items\]"
                foreach item $value {
                    puts "${spaces}  - $item"
                }
            } else {
                # Simple value
                puts "${spaces}$key: $value"
            }
        }
    }

    # Procedure to read an array from a file
    proc read_array_from_file {filename array_name} {
        # Summary:
        # Load array key/value entries from file into an array.
        #
        # Argument Usage:
        # filename array_name
        #
        # Return Value:
        # Integer count of loaded entries, or -1 on failure.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Reads a TCL array from a file that was created by write_array_to_file
        # and stores it in the specified array variable
        #
        # Arguments:
        # filename   - The input filename
        # array_name - The name of the array variable to create/populate
        #
        # Returns:
        # Number of elements loaded on success, -1 on error

        upvar $array_name arr
        set debug 1
        
        if {$debug} {
            puts "-D: Reading array from file: $filename into array '$array_name'"
        }
        
        # Check if file exists
        if {![file exists $filename]} {
            puts "ERROR: File $filename does not exist"
            return -1
        }
        
        # Clear existing array
        if {[array exists arr]} {
            array unset arr
        }
        
        # Read and evaluate the file
        try {
            source $filename
            if {[array exists array_data]} {
                array set arr [array get array_data]
                set count [array size arr]
                if {$debug} {
                    puts "-D: Successfully read array with $count entries"
                }
                return $count
            } else {
                puts "ERROR: No array_data variable found in file $filename"
                return -1
            }
        } trap {TCL} {error_msg} {
            puts "ERROR: Failed to read array from $filename: $error_msg"
            return -1
        }
    }

    # Procedure to read a dictionary from a file
    proc read_dict_from_file {filename} {
        # Summary:
        # Load dictionary content from file and return a Tcl dict.
        #
        # Argument Usage:
        # filename
        #
        # Return Value:
        # Dictionary loaded from file (empty dict on failure/nonexistent file).
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Reads a TCL dictionary from a file that was created by write_dict_to_file
        #
        # Arguments:
        # filename  - The input filename
        #
        # Returns:
        # The dictionary on success, empty dict on error

        set debug 1
        
        if {$debug} {
            puts "-D: Reading dictionary from file: $filename"
        }
        
        # Check if file exists
        if {![file exists $filename]} {
            puts "ERROR: File $filename does not exist"
            return [dict create]
        }
        
        # Read and evaluate the file
        try {
            source $filename
            if {[info exists dict_data]} {
                if {$debug} {
                    puts "-D: Successfully read dictionary with [dict size $dict_data] entries"
                }
                return $dict_data
            } else {
                puts "ERROR: No dict_data variable found in file $filename"
                return [dict create]
            }
        } trap {TCL} {error_msg} {
            puts "ERROR: Failed to read dictionary from $filename: $error_msg"
            return [dict create]
        }
    }

	proc trim_space {mystr} {
		# Summary:
		# Trim leading and trailing whitespace from input string.
		#
		# Argument Usage:
		# mystr
		#
		# Return Value:
		# Trimmed string, or -1 for non-string/list input.
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# this proc trims leading and trailing space
		if {[regexp {^(\s*)(.*?)(\s*)$} $mystr match 1 2 3] ==1} {
			return $2
		} else {
			return -1
		}
	}

    # Procedure to write a TCL array to a file
    proc write_array_to_file {array_name filename {format "readable"}} {
        # Summary:
        # Write array content to file in readable or compact format.
        #
        # Argument Usage:
        # array_name filename {format "readable"}
        #
        # Return Value:
        # Integer status code: 0 on success, 1 on failure.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Writes a TCL array to a file in a specified format
        #
        # Arguments:
        # array_name - The name of the array variable to write (not the array itself)
        # filename   - The output filename
        # format     - Output format: "readable" (human-readable), "compact" (one line), or "serialized"
        #
        # Returns:
        # 0 on success, 1 on error

        upvar $array_name arr
        set debug 1
        
        # Check if array exists
        if {![array exists arr]} {
            puts "ERROR: Array $array_name does not exist"
            return 1
        }
        
        if {$debug} {
            puts "-D: Writing array '$array_name' to file: $filename"
            puts "-D: Format: $format"
            puts "-D: Array size: [array size arr] entries"
        }
        
        # Open file for writing
        if {[catch {open $filename w} fileId]} {
            puts "ERROR: Cannot open file $filename for writing: $fileId"
            return 1
        }
        
        # Write header with metadata
        puts $fileId "# TCL Array File"
        puts $fileId "# Generated on: [clock format [clock seconds]]"
        puts $fileId "# Format: $format"
        puts $fileId "# Array name: $array_name"
        puts $fileId "# Entries: [array size arr]"
        puts $fileId ""
        
        try {
            switch -exact $format {
                "readable" {
                    puts $fileId "# Human-readable array format"
                    puts $fileId "array unset array_data"
                    puts $fileId "array set array_data \{"
                    foreach {key value} [array get arr] {
                        # Handle multi-line values and special characters
                        if {[string first "\n" $value] != -1 || [string first "\{" $value] != -1} {
                            # Value contains newlines or braces, use list format
                            puts $fileId "    [list $key] [list $value]"
                        } else {
                            # Simple key-value pair
                            puts $fileId "    [list $key] [list $value]"
                        }
                    }
                    puts $fileId "\}"
                }
                "compact" {
                    puts $fileId "# Compact array format (one line)"
                    puts $fileId "array unset array_data"
                    puts $fileId "array set array_data [list [array get arr]]"
                }
                "serialized" {
                    puts $fileId "# Serialized array format"
                    puts $fileId "array unset array_data"
                    puts $fileId "array set array_data \{"
                    foreach {key value} [array get arr] {
                        puts $fileId "    [list $key] [list $value]"
                    }
                    puts $fileId "\}"
                }
                default {
                    puts "ERROR: Unknown format '$format'. Using 'readable' format."
                    puts $fileId "# Human-readable array format (default)"
                    puts $fileId "array unset array_data"
                    puts $fileId "array set array_data \{"
                    foreach {key value} [array get arr] {
                        puts $fileId "    [list $key] [list $value]"
                    }
                    puts $fileId "\}"
                }
            }
            
            if {$debug} {
                puts "-D: Successfully wrote array to $filename"
            }
            
        } trap {TCL} {error_msg} {
            puts "ERROR: Failed to write array: $error_msg"
            close $fileId
            return 1
        }
        
        close $fileId
        return 0
    }

    # Procedure to write a dictionary to a file
    proc write_dict_to_file {dict_var filename {format "readable"}} {
        # Summary:
        # Write dictionary content to file in readable or compact format.
        #
        # Argument Usage:
        # dict_var filename {format "readable"}
        #
        # Return Value:
        # Integer status code: 0 on success, 1 on failure.
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Writes a TCL dictionary to a file in a specified format
        #
        # Arguments:
        # dict_var  - The dictionary variable to write
        # filename  - The output filename
        # format    - Output format: "readable" (human-readable), "compact" (one line), or "serialized" (binary)
        #
        # Returns:
        # 0 on success, 1 on error

        set debug 1
        
        if {$debug} {
            puts "-D: Writing dictionary to file: $filename"
            puts "-D: Format: $format"
            puts "-D: Dictionary size: [dict size $dict_var] entries"
        }
        
        # Open file for writing
        if {[catch {open $filename w} fileId]} {
            puts "ERROR: Cannot open file $filename for writing: $fileId"
            return 1
        }
        
        # Write header with metadata
        puts $fileId "# TCL Dictionary File"
        puts $fileId "# Generated on: [clock format [clock seconds]]"
        puts $fileId "# Format: $format"
        puts $fileId "# Entries: [dict size $dict_var]"
        puts $fileId ""
        
        try {
            switch -exact $format {
                "readable" {
                    puts $fileId "# Human-readable dictionary format"
                    puts $fileId "set dict_data \{"
                    dict for {key value} $dict_var {
                        # Handle nested dictionaries and lists
                        if {[catch {dict size $value}] == 0 && [dict size $value] > 0} {
                            # Value is a dictionary
                            puts $fileId "    [list $key] \{"
                            dict for {subkey subvalue} $value {
                                puts $fileId "        [list $subkey] [list $subvalue]"
                            }
                            puts $fileId "    \}"
                        } elseif {[llength $value] > 1} {
                            # Value is a list
                            puts $fileId "    [list $key] \{"
                            foreach item $value {
                                puts $fileId "        [list $item]"
                            }
                            puts $fileId "    \}"
                        } else {
                            # Simple key-value pair
                            puts $fileId "    [list $key] [list $value]"
                        }
                    }
                    puts $fileId "\}"
                }
                "compact" {
                    puts $fileId "# Compact dictionary format (one line)"
                    puts $fileId "set dict_data [list $dict_var]"
                }
                "serialized" {
                    puts $fileId "# Serialized dictionary format"
                    puts $fileId "set dict_data [list"
                    dict for {key value} $dict_var {
                        puts $fileId "    [list $key] [list $value]"
                    }
                    puts $fileId "]"
                }
                default {
                    puts "ERROR: Unknown format '$format'. Using 'readable' format."
                    puts $fileId "# Human-readable dictionary format (default)"
                    puts $fileId "set dict_data \{"
                    dict for {key value} $dict_var {
                        puts $fileId "    [list $key] [list $value]"
                    }
                    puts $fileId "\}"
                }
            }
            
            if {$debug} {
                puts "-D: Successfully wrote dictionary to $filename"
            }
            
        } trap {TCL} {error_msg} {
            puts "ERROR: Failed to write dictionary: $error_msg"
            close $fileId
            return 1
        }
        
        close $fileId
        return 0
    }
}
