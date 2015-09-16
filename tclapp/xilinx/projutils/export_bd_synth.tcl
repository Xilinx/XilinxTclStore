####################################################################################
#
# export_bd_synth.tcl
#
# Script created on 01/27/2015 by Eric Menchen (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1
package require struct::matrix

namespace eval ::tclapp::xilinx::projutils {
  namespace export export_bd_synth
}

namespace eval ::tclapp::xilinx::projutils {
proc export_bd_synth {args} {

  # Summary:
  # Create and write a single design checkpoint and stub files for a Block Design (BD), for use with third party synthesis tools. Perform synthesis as necessary.

  # Argument Usage: 
  # [-force]: Overwrite existing design checkpoint and stub files
  # [-keep]: Keep the temporary directory and project
  # [-verbose]: Print verbose messaging
  # file: The Block Design file to write a synthesized checkpoint for

  # Return Value:
  # (none) An error will be thrown if the command is not successful

  # Categories: synthesis, xilinxtclstore, projutils


  # 0. Handle command line

  ## 0a. Parse arguments
  set force 0
  set verbose 0
  set clean 1
  set sIPIDesign {}
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    switch -exact -- [ lindex $args $index ] {
      {-help}      { puts $helper; return 0 }
      {-force}     { set force 1 }
      {-verbose}   { set verbose 1 }
      {-keep}      { set clean 0 }
      default      { lappend sIPIDesign [ lindex $args $index ] }
    }
  }

  ## 0b. Validate input 
  validate { llength $sIPIDesign } "1" "A single Block Design file object must be provided, received: ${sIPIDesign}"
  validate { get_property CLASS $sIPIDesign } "file" "Only 'file' objects are supported"
  validate { get_property FILE_TYPE $sIPIDesign } "Block Designs" "Only 'Block Design' file types are supported"

  ## Oc. Determine and validate BD directory
  set bdDir [file dirname $sIPIDesign]
  validate { dirIsWritable $bdDir } "1" "Block Design directory '$bdDir' is not writeable"

  # 1. Get and create temporary directory
  set sTmpDir [ mkTmpDir ]
  if { $verbose } { puts "Using temporary directory: $sTmpDir" }

  # 2. Make sure that the IPI design is up-to-date
  generate_target all [ get_files $sIPIDesign ]

  # 3. Remove any IP instances from memory
  #    Note: This must be done since the IPI design is being modified out-of-process
  set_property REGISTERED_WITH_MANAGER 0 [ get_files $sIPIDesign ]

  # 4. Run and catch export_bd_synth_ 
  set failed [ catch { exportBdSynth $sIPIDesign $sTmpDir $force $verbose } returned ] 

  # 5. Re-register (if needed) and clean-up
  set_property REGISTERED_WITH_MANAGER 1 [ get_files $sIPIDesign ]

  # 6. Clean-up if keep was not specified
  if { $clean } {
    if { $verbose } { puts "Attempting to clean-up temporary directory: '${sTmpDir}'" }
    file delete -force $sTmpDir
    if { [ file exists $sTmpDir ] } { puts "Attempt to delete temporary directory failed: '${sTmpDir}'" }
  } else {
    puts "Output files will not be cleaned in directory: '${sTmpDir}'"
  }

  # 7. Re-throw if a failure occurred
  if { $failed } { error $returned }
}
}

namespace eval ::tclapp::xilinx::projutils {

# proc: validate
# Summary:
#   Execute command to validate output is as expected
# Argument Usage: 
#:    validate cmd expected ?failMsg?
# Parameters:
#     cmd            - Command to validate
#     expected       - Expected value of command
#     failMsg        - Message issued on failure to help user identify problem
# Return Value:
#     (none)         - An error is thrown if validation fails
# Example:
#:     # will validate value, in the case an error is thrown
#:     set three 3
#:     validate { eval 2 + 2 } $three "The output of the addition was expected to be '${three}'"
#
proc validate { cmd expected { failMsg {} } } {
  catch { uplevel $cmd } output
  if { $output != $expected } {
    error "\n${failMsg}\n"
  }
}

# proc: dirIsWritable
# Summary:
#   Returns true if the argument supplied is an existing directory and is writable
# Argument Usage: 
#:    dirIsWritable dir
# Parameters:
#     dir            - The directory to test
# Return Value:
#     1              - If directory exists and is writable
#     0              - Otherwise
# Example:
#:     # checks if /tmp exists and is writable
#:     if { [ dirIsWritable "/tmp" ] } { ... }
#
proc dirIsWritable dir {
  if { [ file exists $dir ] && [ file writable $dir ] && [ file isdirectory $dir ] } { return 1 }
  return 0
}

# proc: mkTmpDir
# Summary:
#   Determine unique name in temp location and make dir
# Argument Usage: 
#:    mkTmpDir
# Parameters:
#     (none)         - unused
# Return Value:
#     newTmpDir      - The newly created and unique temp dir, else error
# Example:
#:     # will attempt to identify a unique temporary directory and if 
#:     # possible then the directory will be created
#:     set tmpDir [ mkTmpDir ] 
#
proc mkTmpDir {} {

  set dirPrepend    "bd_checkpoint"
  set dirPostpend   ""
  set tmpDir        ""
  
  # try hard coded directories
  set testTmpDirs [ list [ pwd ] ]
  foreach testTmpDir $testTmpDirs {
    if { [ dirIsWritable $testTmpDir ] } { 
      set tmpDir [ file join $testTmpDir .Xil ]
      file mkdir $tmpDir
      break
    }
  }
  
  # if no temp was found as writable, give up and throw
  if { ( "${tmpDir}" == "" ) || ! [ dirIsWritable $tmpDir ] } {
    error "Failed to find a writable temporary directory!\n  Tried: '${testTmpDirs}'\n"
  }
  
  # we have found a writable temp...
  for { set i 1 } { $i <= 100 } { incr i } {
    set newTmpDir [ file join $tmpDir "${dirPrepend}${i}${dirPostpend}" ]
    if { [ file exists $newTmpDir ] } { continue }
    break
  }
  if { [ file exists $newTmpDir ] } { 
    error "Unable to create a unique temporary directory!\nRemove all temporary directories in: '[ file join ${tmpDir} ${dirPrepend}*${dirPostpend}']"
  }
  file mkdir $newTmpDir
  if { ! [ dirIsWritable $newTmpDir ] } {
    error "Failed to create a writable temporary directory!\nTried: $newTmpDir"
  }
  return $newTmpDir
}

# proc: exportBdSynth
# Summary:
#   Used to synthesize a Block Design (BD) and write out a checkpoint
# Argument Usage: 
#:    exportBdSynth sIPIDesign sTmpDir ?verbose?
# Parameters:
#     sTmpDir        - temporary directory to create project in
#     sIPIDesign     - Block Design object to run synthesis on
#     verbose        - Print verbose messaging
# Return Value:
#     (none)         - unused
# Example:
#:     # export checkpoint with all synthesized IP along with the BD
#:     exportBdSynth [ get_files block_1.bd ] /tmp/user/unique
#
proc exportBdSynth { sIPIDesign sTmpDir { force 0 } { verbose 0 } } {

  # 1. Create a project to perform synthesis

  ## 1a. Record the properties of interest for the diskless project
  set sPart               [ get_property PART                    [ current_project ] ]
  set sSimLanguage        [ get_property SIMULATOR_LANGUAGE      [ current_project ] ]
  set sTargetLanguage     [ get_property TARGET_LANGUAGE         [ current_project ] ]
  set sTargetSimulator    [ get_property TARGET_SIMULATOR        [ current_project ] ]
  set sBoardPartRepoPaths [ get_property BOARD_PART_REPO_PATHS   [ current_project ] ]
  set sBoardPart          [ get_property BOARD_PART              [ current_project ] ]

  ## 1b. Create the project
  set sProject [file tail $sTmpDir]
  create_project $sProject $sTmpDir -part $sPart
  if { $verbose } { puts "Created temporary project '[ get_property NAME [ current_project ] ]' at: '[ get_property DIRECTORY [ current_project ] ]'" }

  ## catch here to close project on failure
  set failed [ catch {

    ## 1c. Set the properties on the project that was just created
    # must support the use of the project property over the parameter for this project
    set_property SIMULATOR_LANGUAGE     $sSimLanguage        [ current_project ] 
    set_property TARGET_LANGUAGE        $sTargetLanguage     [ current_project ] 
    set_property TARGET_SIMULATOR       $sTargetSimulator    [ current_project ] 

    # Must enable editing to change BOARD_PART_REPO_PATHS 
    set bIsEditable [ get_param project.boardPartRepoPaths.editable ]
    set_param project.boardPartRepoPaths.editable 1
    set_property BOARD_PART_REPO_PATHS  $sBoardPartRepoPaths [ current_project ] 
    # Restore editable parameter for BOARD_PART_REPO_PATHS
    set_param project.boardPartRepoPaths.editable $bIsEditable

    set_property BOARD_PART             $sBoardPart          [ current_project ]

    if { $verbose } { puts "Adding BD file to temporary project: '${sIPIDesign}'" } 
    # sIPIDesign is a BD first-class object, we convert to string to read in from file path
    set sTmpIPIDesign [ add_files "${sIPIDesign}" ] 

    # Synthesize the design
    #if { $verbose } { puts "Using command to run synthesis: synth_design -top $bdName -part $sPart -mode out_of_context" }
    #synth_design -top $bdName -part $sPart -mode out_of_context
    set bdName [file rootname [file tail $sIPIDesign] ]
    if { $verbose } { puts "Setting top for synthesis to $bdName" }
    set_property top $bdName [get_filesets sources_1]
    if { $verbose } { puts "Configuring synthesis run with option: -mode out_of_context" }
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    if { $verbose } { puts "Launching synthesis run with command: launch_runs synth_1" }
    launch_runs synth_1
    wait_on_run synth_1
    if { $verbose } { puts "Synthesis of $sTmpIPIDesign complete" }

    # Stitch everything together.
    # This is not needed when synth_design is used; is needed for launch_runs - wait_on_run
    if { $verbose } { puts "Opening synthesized design" }
    open_run synth_1

    # Write out the files.
    set bdDir [file dirname $sIPIDesign]
    set stubFile [file join $bdDir "${bdName}_stub.v"]
    if { $verbose } { puts "Writing Verilog stub file $stubFile" }
    # Not the most elegant -force handling, but works.
    if { $force } {
      write_verilog -force -mode synth_stub $stubFile
    } else {
      write_verilog -mode synth_stub $stubFile
    }
    append stubFile "hd"
    if { $verbose } { puts "Writing VHDL stub file $stubFile" }
    if { $force } {
      write_vhdl -force -mode synth_stub $stubFile
    } else {
      write_vhdl -mode synth_stub $stubFile
    }
    set checkpointFile [file join $bdDir "${bdName}.dcp"]
    if { $verbose } { puts "Writing checkpoint file $checkpointFile" }
    if { $force } {
      write_checkpoint -force $checkpointFile
    } else {
      write_checkpoint $checkpointFile
    }

  } returned ]

  # 5. Cleanup after ourselves
  # TODO: What do we do with the synthesis log output (e.g. echo it out to the console)?
  close_project

  if { $failed } { error $returned }

}

}


