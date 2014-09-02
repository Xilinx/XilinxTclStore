####################################################################################
#
# convert_ngc.tcl (write a Vivado project tcl script for re-creating project)
#
# Script created on 09/01/2014 by Nik Cimino Xilinx, Inc.)
#
# 2014.3 - v1.0 (rev 1)
#  * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export convert_ngc
}

namespace eval ::tclapp::xilinx::projutils {

proc convert_ngc args {
  # Summary: 
  # Convert all provided NGC files to 

  # Argument Usage: 
  # [-output_dir <arg> = Script output directory path]: Directory to place all output, else the output is placed at location of NGC file
  # [-format]: Format as Verilog, else EDIF is produced]: Specifies the desired output format
  # [-add_to_project]: Adds the output files to the current project, if no project is open, then this option does nothing
  # [-force]: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified
  # files: A list of NGC files to convert

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, projutils

  # member variables
  variable m_options
  init_vars_
 
  # process options
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    set option [ string trim [ lindex $args $index ] ]
    switch -regexp -- $option {
      "-output_dir"           { incr index; set m_options(sOutputDir) [ lindex $args $index ] }
      "-format"               { set m_options(bFormat) 1 }
      "-add_to_project"       { set m_options(bAddToProject) 1 }
      "-force"                { set m_options(bForce) 1 }
      "-verbose"              { set m_options(bVerbose) 1 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-projutils-301 ERROR "Unknown option '$option', please type 'convert_ngc -help' for usage info.\n"
          return 1
        }
        foreach file $option {
          lappend m_options(files) $file
        }
      }
    }
  }

  # all files must exist
  if { [ llength $m_options(files) ] == 0 } {
    send_msg_id Vivado-projutils-302 ERROR "Missing value for option 'files', please type 'convert_ngc -help' for usage info.\n"
    return 1
  }
  set bFilesAreMissing 0
  foreach file $m_options(files) {
    if { ! [ file exists $file ] } {
      send_msg_id Vivado-projutils-303 {CRITICAL WARNING} "Specified file does not exist: '${file}'\n"
      set bFilesAreMissing 1
    }
  }
  if { $bFilesAreMissing } {
    send_msg_id Vivado-projutils-304 ERROR "Some files could not be found, see previous messages for more details\n"
  }

  # verify that the output dir can be created, exists after creating, is a dir, and is writable
  if { [ string length $m_options(sOutputDir) ] != 0 } {
    if { ! [ file exists $m_options(sOutputDir) ] } {
      file mkdir $m_options(sOutputDir)
      if { ! [ file exists $m_options(sOutputDir) ] } {
        send_msg_id Vivado-projutils-305 ERROR "Unable to create directory: '$m_options(sOutputDir)'"
      }
    }
    if { ! [ file isdirectory $m_options(sOutputDir) ] } {
      send_msg_id Vivado-projutils-306 ERROR "The '-output_dir' must point to a directory, this is not a directory: '$m_options(sOutputDir)'"
    }
    if { ! [ file writable $m_options(sOutputDir) ] } {
      send_msg_id Vivado-projutils-307 ERROR "The '-output_dir' specified is not writable: '$m_options(sOutputDir)'"
    }
  }

  # end of business logic 

  # perform conversion
  send_msg_id Vivado-projutils-300 INFO "Converting all provided files..."
  if { $m_options(bFormat) } {
    send_msg_id Vivado-projutils-307 ERROR "The convert_ngc command does not currently support conversion to Verilog"
  } else {
    convert_ngcs_to_edif_ $m_options(files) $m_options(sOutputDir) $m_options(bAddToProject) $m_options(bForce) $m_options(bVerbose)
  }

}


proc init_vars_ {} {
  
  # member variables
  variable m_options
  
  array unset m_options
  set m_options(sOutputDir)     {}
  set m_options(bFormat)        0
  set m_options(bAddToProject)  0 
  set m_options(bForce)         0
  set m_options(bVerbose)       0
  set m_options(files)          {}
}


proc convert_ngcs_to_edif_ { _ngcFiles _sOutputDir _bAddToProject _bForce _bVerbose } {

  # track success and failures, but continue on failures
  set ngcsFailed {}
  set ngcsSucceeded {}
  
  foreach sNgcFile $_ngcFiles {
    set sCanonicalNgcFile [ file normalize $sNgcFile ] 
    if { [ catch { convert_ngc_to_edif_ $sCanonicalNgcFile $_sOutputDir $_bForce } _error ] } {
      send_msg_id Vivado-projutils-308 {CRITICAL WARNING} "Failed to convert NGC file '${sCanonicalNgcFile}' error message was:\n[ string trim ${_error} ]\n"
      lappend ngcsFailed $sCanonicalNgcFile
    } else {
      lappend ngcsSucceeded $sCanonicalNgcFile
    }
  }

  # add the file to the project if specified
  if { $_bAddToProject } {
    # if there isn't a project open, then don't do anything
    if { [ catch { current_project } _error ] } {
      send_msg_id Vivado-projutils-316 {CRITICAL WARNING} "Could not add converted files to project because a project is not open.\n"
    } else {
      if { $_bForce } {
        remove_files -quiet $ngcsSucceeded
      }
      if { [ catch { add_files $ngcsSucceeded } _addError ] } {
        send_msg_id Vivado-projutils-314 {CRITICAL WARNING} "Failed to add converted files to project:\n[ string trim ${_addError} ]\n"
      } else {
        send_msg_id Vivado-projutils-317 INFO "Added all successfully converted files to project."
      }
    }
  }

  # report results
  if { $_bVerbose && ( [ llength $ngcsSucceeded ] > 0 ) } {
    send_msg_id Vivado-projutils-309 INFO "Successfully converted NGC files:\n  [ join $ngcsSucceeded \n\ \  ]"
  }
  if { [ llength $ngcsFailed ] > 0 } {
    send_msg_id Vivado-projutils-310 INFO "Failed to convert NGC files:\n  [ join $ngcsFailed \n\ \  ]"
  }
  if { [ llength $ngcsSucceeded ] > 0 } {
    send_msg_id Vivado-projutils-311 INFO "Successfully converted [ llength $ngcsSucceeded ] NGC file(s)."
  }
  if { [ llength $ngcsFailed ] > 0 } {
    send_msg_id Vivado-projutils-312 INFO "Failed to convert [ llength $ngcsFailed ] NGC file(s)."
  }
  if { [ llength $ngcsFailed ] > 0 } {
    send_msg_id Vivado-projutils-313 ERROR "Failed to convert one or more NGC files, see previous messages for details"
  }

}


proc convert_ngc_to_edif_ { _sNgcFile _sOutputDir _bForce } {

  # calculate output file name
  set sOutputFile [ calculate_output_file_ $_sNgcFile $_sOutputDir "edn" ]
  set sOutputLog [ calculate_output_file_ $_sNgcFile $_sOutputDir "log" ]

  # cleanup existing files if -force specified else error
  if { [ file exists $sOutputFile ] } {
    if { ! $_bForce } {
      send_msg_id Vivado-projutils-314 ERROR "Output file exists, to overwrite specify -force: '${sOutputFile}'\n"
    }
  #  file delete -force $sOutputFile
  }

  # build command
  set command "ngc2edif"

  set commandPath [ auto_execok $command ] 
  if { [ string length $commandPath ] == 0 } {
    send_msg_id Vivado-projutils-315 ERROR "Failed to find the ngc2edif executable. Check to see if ngc2edif works from the Vivado shell.\n"
  }

  if { $_bForce } {
    lappend command "-w"
  }
  
  #lappend command "-log"
  #lappend command $sOutputLog

  lappend command $_sNgcFile
  
  lappend command $sOutputFile

  # throws are caught by caller
  eval "exec ${command}"

}


proc calculate_output_file_ { _sNgcFile _sOutputDir _sExtension } {

  set sRootName [ file rootname $_sNgcFile ]
  
  if { [ string length $_sOutputDir ] != 0 } {
    set sFileName [ file tail $sRootName ]
    set sRootName [ file join ${_sOutputDir} ${sFileName} ]
  }

  set sOutputFile "${sRootName}.${_sExtension}"

  return $sOutputFile

}


}; # end namespace ::tclapp::xilinx::projutils
