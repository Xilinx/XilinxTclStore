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
  # Convert all provided NGC files to a supported format

  # Argument Usage: 
  # [-output_dir <arg> = Script output directory path]: Directory to place all output, else the output is placed at location of NGC file
  # [-format <arg> = EDIF]: Accepts 'Verilog' or 'EDIF' (Default: EDIF), specifies the desired output format
  # [-add_to_project]: Adds the output files to the current project, if no project is open, then this option does nothing
  # [-force]: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified
  # files: A list of NGC files to convert

  # Return Value:
  # None

  # Categories: xilinxtclstore, projutils

  # member variables
  variable m_ngc_options
  init_ngc_vars_
 
  # process options
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    set option [ string trim [ lindex $args $index ] ]
    switch -regexp -- $option {
      "-output_dir"           { incr index; set m_ngc_options(sOutputDir) [ lindex $args $index ] }
      "-format"               { incr index; set m_ngc_options(sFormat)    [ lindex $args $index ] }
      "-add_to_project"       { set m_ngc_options(bAddToProject) 1 }
      "-force"                { set m_ngc_options(bForce) 1 }
      "-verbose"              { set m_ngc_options(bVerbose) 1 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-projutils-301 ERROR "Unknown option '$option', please type 'convert_ngc -help' for usage info.\n"
          return 1
        }
        # positional
        foreach file $option {
          lappend m_ngc_options(files) $file
        }
      }
    }
  }

  # all files must exist
  if { [ llength $m_ngc_options(files) ] == 0 } {
    send_msg_id Vivado-projutils-302 ERROR "Missing value for option 'files', please type 'convert_ngc -help' for usage info.\n"
    return 1
  }
  set bFilesAreMissing 0
  foreach file $m_ngc_options(files) {
    if { ! [ file exists $file ] } {
      send_msg_id Vivado-projutils-303 {CRITICAL WARNING} "Specified file does not exist: '${file}'\n"
      set bFilesAreMissing 1
    }
  }
  if { $bFilesAreMissing } {
    send_msg_id Vivado-projutils-304 ERROR "Some files could not be found, see previous messages for more details\n"
  }

  # verify that the output dir can be created, exists after creating, is a dir, and is writable
  if { [ string length $m_ngc_options(sOutputDir) ] != 0 } {
    if { ! [ file exists $m_ngc_options(sOutputDir) ] } {
      file mkdir $m_ngc_options(sOutputDir)
      if { ! [ file exists $m_ngc_options(sOutputDir) ] } {
        send_msg_id Vivado-projutils-305 ERROR "Unable to create directory: '$m_ngc_options(sOutputDir)'"
      }
    }
    if { ! [ file isdirectory $m_ngc_options(sOutputDir) ] } {
      send_msg_id Vivado-projutils-306 ERROR "The '-output_dir' must point to a directory, this is not a directory: '$m_ngc_options(sOutputDir)'"
    }
    if { ! [ file writable $m_ngc_options(sOutputDir) ] } {
      send_msg_id Vivado-projutils-307 ERROR "The '-output_dir' specified is not writable: '$m_ngc_options(sOutputDir)'"
    }
  }

  send_msg_id Vivado-projutils-322 INFO "The convert_ngc command does not support encrypted NGC files. If an encrypted NGC is converted, then the output netlist will have all LUTs set to zero."

  # end of business logic 

  # perform conversion
  if { [ string match -nocase "$m_ngc_options(sFormat)" "verilog" ] } {
    send_msg_id Vivado-projutils-320 INFO "Converting NGC files to Verilog..."
    convert_ngcs_to_verilog_ $m_ngc_options(files) $m_ngc_options(sOutputDir) $m_ngc_options(bAddToProject) $m_ngc_options(bForce) $m_ngc_options(bVerbose)
  } elseif { [ string match -nocase "$m_ngc_options(sFormat)" "edif" ] } {
    send_msg_id Vivado-projutils-319 INFO "Converting NGC files to EDIF..."
    convert_ngcs_to_edif_ $m_ngc_options(files) $m_ngc_options(sOutputDir) $m_ngc_options(bAddToProject) $m_ngc_options(bForce) $m_ngc_options(bVerbose)
  } else {
    send_msg_id Vivado-projutils-318 ERROR "Unknown value '$m_ngc_options(sFormat)' provided for switch -format, expected 'EDIF' or 'Verilog'"
  }

}



##########
# Common #
##########


proc init_ngc_vars_ {} {
  # Summary: 
  # Initialize all member variables

  # Argument Usage: 
  # None

  # Return Value:
  # None
  
  # member variables
  variable m_ngc_options
  variable m_sEdifExt
  variable m_sVerilogExt
  variable m_sLogExt
  variable m_bDebugLogs
  
  array unset m_ngc_options
  set m_ngc_options(sOutputDir)     ""
  set m_ngc_options(sFormat)        "EDIF"
  set m_ngc_options(bAddToProject)  0 
  set m_ngc_options(bForce)         0
  set m_ngc_options(bVerbose)       0
  set m_ngc_options(files)          [list]

  # static
  set m_sVerilogExt             ".v"
  set m_sEdifExt                ".edn"
  set m_sLogExt                 ".log"
  set m_bDebugLogs              0
}


proc calculate_output_file_ { _sNgcFile _sOutputDir _sExtension } {
  # Summary: 
  # Determines the output file. If a directory is provided, then the output file points to that 
  # directory, else the output file points to the same directory location as the source.

  # Argument Usage: 
  # _sNgcFile: A NGC file to calculate the output file name for
  # _sOutputDir: Directory to place output, else the output is placed at location of NGC file
  # _sExtension: The output file extension

  # Return Value:
  # The calculated output file path

  set sRootName [ file rootname $_sNgcFile ]
  
  if { [ string length $_sOutputDir ] != 0 } {
    set sFileName [ file tail $sRootName ]
    set sRootName [ file join ${_sOutputDir} ${sFileName} ]
  }

  set sOutputFile "${sRootName}${_sExtension}"

  return $sOutputFile
}

proc add_ngc_conversions_to_project_ { _ngcFilesToAdd _sOutputDir _sExtension _bForce } {
  # Summary: 
  # Adds the listed files to the project

  # Argument Usage: 
  # _filesToAdd: List of files to add to the project
  # _bForce: Removes the old files from the project before adding, ensuring new files are added

  # Return Value:
  # None

  set filesToAdd {}
  foreach ngcFile $_ngcFilesToAdd {
    lappend filesToAdd [ calculate_output_file_ $ngcFile $_sOutputDir $_sExtension ]
  }

  if { [ catch { current_project } _error ] } {
    send_msg_id Vivado-projutils-316 {CRITICAL WARNING} "Could not add converted files to project because a project is not open.\n"
  } else {
    if { $_bForce } {
      catch { remove_files -quiet $filesToAdd } _removeError
    }
    if { [ catch { add_files $filesToAdd } _addError ] } {
      send_msg_id Vivado-projutils-314 {CRITICAL WARNING} "Failed to add converted files to project:\n[ string trim ${_addError} ]\n"
    } else {
      send_msg_id Vivado-projutils-317 INFO "Added all successfully converted files to project."
    }
  }
}

proc report_results_ { _ngcsSucceeded _ngcsFailed _bVerbose } {
  # Summary: 
  # Reports the conversion results (which files succeeded and which failed conversion)

  # Argument Usage: 
  # _ngcsSucceeded: List of successfully converted NGCs
  # _ngcsFailed: List of NGCs that failed conversion
  # _bVerbose: Prints verbose messaging

  # Return Value:
  # None (messages printed)

  if { $_bVerbose && ( [ llength $_ngcsSucceeded ] > 0 ) } {
    send_msg_id Vivado-projutils-309 INFO "Successfully converted NGC files:\n  [ join $_ngcsSucceeded \n\ \  ]"
  }
  if { [ llength $_ngcsFailed ] > 0 } {
    send_msg_id Vivado-projutils-310 INFO "Failed to convert [ llength $_ngcsFailed ] NGC file(s):\n  [ join $_ngcsFailed \n\ \  ]"
  }
  if { [ llength $_ngcsSucceeded ] > 0 } {
    send_msg_id Vivado-projutils-311 INFO "Successfully converted [ llength $_ngcsSucceeded ] NGC file(s)."
  }
  #if { [ llength $_ngcsFailed ] > 0 } {
  #  send_msg_id Vivado-projutils-312 INFO "Failed to convert [ llength $_ngcsFailed ] NGC file(s)."
  #}
  if { [ llength $_ngcsFailed ] > 0 } {
    send_msg_id Vivado-projutils-313 ERROR "Failed to convert one or more NGC files, see previous messages for details"
  }
}


###########
# Verilog #
###########


proc convert_ngcs_to_verilog_ { _ngcFiles _sOutputDir _bAddToProject _bForce _bVerbose } {
  # Summary: 
  # Convert all provided NGC files to Verilog format

  # Argument Usage: 
  # _ngcFiles: A list of NGC files to convert
  # _sOutputDir: Directory to place all output, else the output is placed at location of NGC file
  # _bAddToProject: Adds the output files to the current project, if no project is open, then this option does nothing
  # _bForce: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified
  # _bVerbose: Print verbose messages

  # Return Value:
  # None

  variable m_sVerilogExt

  # track success and failures, but continue on failures
  set ngcsFailed {}
  set ngcsSucceeded {}
  
  foreach sNgcFile $_ngcFiles {
    set sCanonicalNgcFile [ file normalize $sNgcFile ] 
    if { [ catch { convert_ngc_to_verilog_ $sCanonicalNgcFile $_sOutputDir $_bForce } _error ] } {
      # Lower level commands always end with cause by general Tcl Interp
      #   ERROR: [Common 17-39] 'send_msg_id' failed due to earlier errors.
      #send_msg_id Vivado-projutils-308 {CRITICAL WARNING} "Failed to convert NGC file '${sCanonicalNgcFile}' error message was:\n[ string trim ${_error} ]\n"
      send_msg_id Vivado-projutils-321 {CRITICAL WARNING} "Failed to convert NGC file '${sCanonicalNgcFile}', continuing with other NGC coversions...\n"
      lappend ngcsFailed $sCanonicalNgcFile
    } else {
      lappend ngcsSucceeded $sCanonicalNgcFile
    }
  }

  if { $_bAddToProject } {
    add_ngc_conversions_to_project_ $ngcsSucceeded $_sOutputDir $m_sVerilogExt $_bForce
  }

  report_results_ $ngcsSucceeded $ngcsFailed $_bVerbose
}


proc convert_ngc_to_verilog_ { _sNgcFile _sOutputDir _bForce } {
  # Summary: 
  # Convert a provided NGC file to Verilog format

  # Argument Usage: 
  # _ngcFile: A NGC file to convert
  # _sOutputDir: Directory to place all output, else the output is placed at location of NGC file
  # _bForce: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified

  # Return Value:
  # None

  variable m_sVerilogExt
  variable m_sLogExt
  variable m_bDebugLogs

  # calculate output file name
  set sOutputFile [ calculate_output_file_ $_sNgcFile $_sOutputDir $m_sVerilogExt ]
  set sOutputLog [ calculate_output_file_ $_sNgcFile $_sOutputDir $m_sLogExt ]

  # cleanup existing files if -force specified else error
  set sForceCmd ""
  if { [ file exists $sOutputFile ] } {
    if { ! $_bForce } {
      send_msg_id Vivado-projutils-314 ERROR "Output file exists, to overwrite specify -force: '${sOutputFile}'\n"
    } 
  }
  if { $_bForce } {
    set sForceCmd " -force"
  }

  set sLogCmd " -quiet"
  if { $m_bDebugLogs } {
    file delete -force $sOutputLog ; # comment for append
    set sLogCmd " >> $sOutputLog"
  }

  # store currently open project if there is one
  set currentProject [ current_project -quiet ]

  # convert
  set sConversionProject "Ngc2VerilogConversionProject"
  # if there was already a Ngc2VerilogConversionProject opened, then Ngc2VerilogConversionProject(2)
  # is created, and this is what will be stored in sCreatedProject
  set sCreatedProject [ create_project -in_memory $sConversionProject $_sOutputDir ]
  current_project $sCreatedProject
  set_property design_mode GateLvl [ current_fileset -srcset ]
  read_edif $_sNgcFile
  eval "link_design${sLogCmd}"
  eval "write_verilog -mode design ${sOutputFile}${sForceCmd}${sLogCmd}"
  close_project

  # restore previous project as current, if it was set
  if { [ llength $currentProject ] == 1 } {
    current_project $currentProject
  }
}



########
# EDIF #
########


proc convert_ngcs_to_edif_ { _ngcFiles _sOutputDir _bAddToProject _bForce _bVerbose } {
  # Summary: 
  # Convert all provided NGC files to EDIF format

  # Argument Usage: 
  # _ngcFiles: A list of NGC files to convert
  # _sOutputDir: Directory to place all output, else the output is placed at location of NGC file
  # _bAddToProject: Adds the output files to the current project, if no project is open, then this option does nothing
  # _bForce: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified
  # _bVerbose: Print verbose messages

  # Return Value:
  # None

  variable m_sEdifExt

  # track success and failures, but continue on failures
  set ngcsFailed {}
  set ngcsSucceeded {}
  
  foreach sNgcFile $_ngcFiles {
    set sCanonicalNgcFile [ file normalize $sNgcFile ] 
    if { [ catch { convert_ngc_to_edif_ $sCanonicalNgcFile $_sOutputDir $_bForce } _error ] } {
      # Lower level commands always end with cause by general Tcl Interp
      #   ERROR: [Common 17-39] 'send_msg_id' failed due to earlier errors.
      #send_msg_id Vivado-projutils-308 {CRITICAL WARNING} "Failed to convert NGC file '${sCanonicalNgcFile}' error message was:\n[ string trim ${_error} ]\n"
      send_msg_id Vivado-projutils-321 {CRITICAL WARNING} "Failed to convert NGC file '${sCanonicalNgcFile}', continuing with other NGC coversions...\n"
      lappend ngcsFailed $sCanonicalNgcFile
    } else {
      lappend ngcsSucceeded $sCanonicalNgcFile
    }
  }

  if { $_bAddToProject } {
    add_ngc_conversions_to_project_ $ngcsSucceeded $_sOutputDir $m_sEdifExt $_bForce
  }

  report_results_ $ngcsSucceeded $ngcsFailed $_bVerbose
}


proc convert_ngc_to_edif_ { _sNgcFile _sOutputDir _bForce } {
  # Summary: 
  # Convert a provided NGC file to EDIF format

  # Argument Usage: 
  # _ngcFile: A NGC file to convert
  # _sOutputDir: Directory to place all output, else the output is placed at location of NGC file
  # _bForce: Force overwriting of files that already exist on disk, replaces files in project if add_to_project switch was specified

  # Return Value:
  # None

  variable m_sEdifExt
  variable m_sLogExt
  variable m_bDebugLogs

  # calculate output file name
  set sOutputFile [ calculate_output_file_ $_sNgcFile $_sOutputDir $m_sEdifExt ]
  set sOutputLog [ calculate_output_file_ $_sNgcFile $_sOutputDir $m_sLogExt ]

  # cleanup existing files if -force specified else error
  if { [ file exists $sOutputFile ] } {
    if { ! $_bForce } {
      send_msg_id Vivado-projutils-314 ERROR "Output file exists, to overwrite specify -force: '${sOutputFile}'\n"
    }
    # Not needed because -w is specified on ngc2edif
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
  
  if { $m_bDebugLogs } {
    lappend command "-log"
    lappend command $sOutputLog
  }

  lappend command $_sNgcFile
  
  lappend command $sOutputFile

  # throws are caught by caller
  eval "exec ${command}"
}


}; # end namespace ::tclapp::xilinx::projutils
