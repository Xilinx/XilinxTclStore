package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export write_template
}

proc ::tclapp::xilinx::designutils::write_template {args} {
  # Summary : Generates a Verilog/VHDL stub or instantiation template for the current design in memory (current_instance)

  # Argument Usage:
  # [-type <arg> = stub]: Type of template to create: stub or template
  # [-stub]: Generate a stub (same as -type stub)
  # [-template]: Generate a template (same as -type template)
  # [-language <arg> = verilog]: Output language of the template: verilog or vhdl
  # [-verilog]: Verilog language (same as -language verilog)
  # [-vhdl]: VHDL language (same as -language vhdl)
  # [-cell <arg> = current_instance]: Cell to generate template on. If not specified, runs on current_instance
  # [-file <arg> = <module>.v or <module>.vhd]: Output file name
  # [-append]: Append to file
  # [-return_string]: Return template as string
  # [-usage]: Usage information

  # Return Value:
  # template in the case of -return_string, otherwise 0 TCL_ERROR if error

  # Categories: xilinxtclstore, designutils
  return [uplevel ::tclapp::xilinx::designutils::write_template::write_template $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::write_template {
   variable version {01-14-2014}
   variable tfh {}
   variable module {}
   variable inputBitPorts {}
   variable inputBusPorts
   variable outputBitPorts {}
   variable outputBusPorts
   variable inoutBitPorts {}
   variable inoutBusPorts
} ]

# ##############################################################
# Generates verilog or vhdl templates for current_instance or
# specfied cell.
# - Requires design loaded in memory
# - Generates stub, instantitation template, or testbench
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::write_template { args } {
  # Summary :

  # Argument Usage:
  # args : command line option (-help option for more details)

  # Return Value:
  # template in the case of -return_string, otherwise 0
  # TCL_ERROR if error

  # Categories: xilinxtclstore, designutils

  variable tfh
  variable module
  variable inputBitPorts
  variable inputBusPorts
  variable outputBitPorts
  variable outputBusPorts
  variable inoutBitPorts
  variable inoutBusPorts

  # set default values
  catch {unset inputBusPorts}
  catch {unset outputBusPorts}
  catch {unset inoutBusPorts}
  set tfh {}

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set help 0
  set filename {}
  set type {stub}
  set language {verilog}
  set mode {w}
  set cell {}
  set returnString 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -type -
      {^-ty(pe?)?$} {
           set type [string tolower [lshift args]]
           if {![regexp {^(stub|template)$} $type]} {
             incr error
             puts " -E- the supported values for -type are stub or template"
           }
      }
      -stub -
      {^-s(t(ub?)?)?$} {
           set type {stub}
      }
      -template -
      {^-tem(p(l(a(te?)?)?)?)?$} {
           set type {template}
      }
      -language -
      {^-l(a(n(g(u(a(ge?)?)?)?)?)?)?$} {
           set language [string tolower [lshift args]]
           if {![regexp {^(verilog|vhdl)$} $language]} {
             incr error
             puts " -E- the supported values for -language are verilog or vhdl"
           }
      }
      -verilog -
      {^-ve(r(i(l(og?)?)?)?)?$} {
           set language {verilog}
      }
      -vhdl -
      {^-vh(dl?)?$} {
           set language {vhdl}
      }
      -cell -
      {^-c(e(ll?)?)?$} {
           set cell [lshift args]
      }
      -file -
      {^-f(i(le?)?)?$} {
           set filename [lshift args]
           if {$filename == {}} {
             puts " -E- no filename specified."
             incr error
           }
      }
      -append -
      {^-a(p(p(e(nd?)?)?)?)?$} {
           set mode {a}
      }
      -return_string -
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            } else {
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            }
      }
    }
  }

  if {$cell != {}} {
    set cellObj [get_cells -quiet $cell]
    if {$cellObj == {}} {
      puts " -E- specified cell $cell could not be found in design"
      incr error
    } else {
      set cell $cellObj
    }
  }

  if {$help} {
    puts [format {
  Usage: write_template
              [-type <arg>]        - Type of template to create
                                     Options are: stub or template
              [-stub]              - Generate a stub (same as -type stub)
              [-template]          - Generate a template (same as -type template)
              [-language <arg>]    - Output language of the template
                                     Options are: verilog or vhdl
              [-verilog]           - Verilog language (same as -language verilog)
              [-vhdl]              - VHDL language (same as -language vhdl)
              [-cell <arg>]        - Cell to generate template on. If not specified,
                                     runs on current_instance
              [-file <arg>]        - Output file name
                                     Default: <module>.v or <module>.vhd
              [-append]            - Append to file
              [-return_string]     - Return template as string
              [-usage|-u]          - This help message

  Description: Writes out Verilog or VHDL templates

     This command generates Verilog or VHDL templates for:
       template: -template or -type template
       blackbox stub definition: -stub or -type stub

  Example:
     write_template
     write_template -verilog -stub -file top.v
     write_template -vhdl -template -cell ila_v2_1_0 -return_string
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # If no design is open
  if { [catch {current_instance -quiet .}]} {
    set errMsg "ERROR: No open design. A design must be open to run this command."
    error $errMsg
  }

  # Save the current instance we are in so that it can be restored afterward
  set current_instance [current_instance -quiet .]

  # Define module name and if command is being run on top or a cell
  if {$cell != {}} {
    set module [get_property -quiet REF_NAME $cell]
    set isTop 0
  } else {
    # If top-level, then $current_instance is empty
    if {$current_instance == {}} {
      set module [get_property -quiet TOP [current_design]]
      set isTop 1
    } else {
      # We need to change to the top-level so that the list of pins can be extracted from
      # the current instance
      current_instance -quiet
      set module [get_property -quiet REF_NAME [get_cells -quiet $current_instance]]
      set isTop 0
      set cell $current_instance
    }
  }

  # Generate the default file name
  if {$filename == {}} {
    if {$language == {verilog}} {
      set filename "${module}.v"
    } else {
      set filename "${module}.vhd"
    }
  }

  # Get a sorted list of all input and output bit and busses
  # If no -cell, this is a list of ports as input and output
  # If a cell is specified, a list of pins is given, but a scoped port list is returned
  if {$isTop} {
    # Build data structures for IN ports
    set inPorts [lsort [get_ports -quiet -filter DIRECTION==IN]]
    array set inputBusPorts [list ]
    set inputBitPorts [list]
    sortPorts $inPorts inputBusPorts inputBitPorts

    # Build data structures for OUT ports
    set outPorts [lsort [get_ports -quiet -filter DIRECTION==OUT]]
    array set outputBusPorts [list ]
    set outputBitPorts [list]
    sortPorts $outPorts outputBusPorts outputBitPorts

    # Build data structures for INOUT ports
    set inoutPorts [lsort [get_ports -quiet -filter DIRECTION==INOUT]]
    array set inoutBusPorts [list ]
    set inoutBitPorts [list]
    sortPorts $inoutPorts inoutBusPorts inoutBitPorts
  } else {
    # Build data structures for IN ports
    set inPins [lsort [get_pins -quiet -of [get_cells -quiet $cell] -filter DIRECTION==IN]]
    array set inputBusPorts [list ]
    set inputBitPorts [list]
    sortPins $inPins inputBusPorts inputBitPorts

    # Build data structures for OUT ports
    set outPins [lsort [get_pins -quiet -of [get_cells -quiet $cell] -filter DIRECTION==OUT]]
    array set outputBusPorts [list ]
    set outputBitPorts [list]
    sortPins $outPins outputBusPorts outputBitPorts

    # Build data structures for INOUT ports
    set inoutPins [lsort [get_pins -quiet -of [get_cells -quiet $cell] -filter DIRECTION==INOUT]]
    array set inoutBusPorts [list ]
    set inoutBitPorts [list]
    sortPorts $inoutPins inoutBusPorts inoutBitPorts
  }

  if {[string match $type "stub"]} {
    if {[string match $language "verilog"]} {
      set content [vlogStub]
    } elseif {[string match $language "vhdl"]} {
      set content [vhdlStub]
    }
  } elseif {[string match $type "template"]} {
    if {[string match $language "verilog"]} {
      set content [vlogTemplate]
    } elseif {[string match $language "vhdl"]} {
      set content [vhdlTemplate]
    }
  }

  # Save the template
  puts "\nCreating $language $type for Module $module in [file normalize $filename]"
  set tfh [open $filename $mode]
  puts $tfh $content
  close $tfh

  # Go back to the instance level we were in before calling this command
  if {$current_instance != {}} {
    current_instance -quiet
    current_instance -quiet $current_instance
  } else {
    current_instance -quiet
  }

  # Return result as string?
  if {$returnString} {
    return $content
  }

  return 0
}

# ##############################################################
# Generates a Verilog instantiation template for the specified
# module.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vlogTemplate {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # Verilog template

  # Categories: xilinxtclstore, designutils

  variable module
  variable inputBitPorts
  variable inputBusPorts
  variable outputBitPorts
  variable outputBusPorts
  variable inoutBitPorts
  variable inoutBusPorts

  set lines [list]
  # Process input single bit ports
  lappend lines "\/\/ Input Ports - Single Bit"
  foreach port [lsort -dictionary $inputBitPorts] {
    lappend lines ".${port} ($port),"
  }
  # Process input bus ports
  lappend lines "\/\/ Input Ports - Busses"
  foreach {port busInfo} [array2sortedList inputBusPorts] {
    lassign $busInfo width stop start
    lappend lines ".${port}\[$start:$stop\] ($port\[$start:$stop\]),"
  }
  # Process output single bit ports
  lappend lines "\/\/ Output Ports - Single Bit"
  foreach port [lsort -dictionary $outputBitPorts] {
    lappend lines ".${port} ($port),"
  }
  # Process output bus ports
  lappend lines "\/\/ Output Ports - Busses"
  foreach {port busInfo} [array2sortedList outputBusPorts] {
    lassign $busInfo width stop start
    lappend lines ".${port}\[$start:$stop\] ($port\[$start:$stop\]),"
  }
  # Process inout single bit ports
  lappend lines "\/\/ InOut Ports - Single Bit"
  foreach port [lsort -dictionary $inoutBitPorts] {
    lappend lines ".${port} ($port),"
  }
  # Process inout bus ports
  lappend lines "\/\/ InOut Ports - Busses"
  foreach {port busInfo} [array2sortedList inoutBusPorts] {
    lassign $busInfo width stop start
    lappend lines ".${port}\[$start:$stop\] ($port\[$start:$stop\]),"
  }

  # Detect maximum column width to align columns
  foreach line $lines {
    if {[regexp {^\s*\/\/} $line]} {
      # Skip lines that are just comments
      continue
    }
    set width [string length [lindex $line 0]]
    if {![info exist maxWidth] || $maxWidth < $width} {
      set maxWidth $width
    }
  }

  # Build the content of the template:
  # Construct Formatted lines to align columns and print each line to output file
  set content "$module ${module}_inst ("
  foreach line $lines {
    if {[regexp {^\s*\/\/} $line]} {
      # Lines that are just comments
      append content "\n   $line"
      continue
    }
    append content [format "\n   %-${maxWidth}s %-${maxWidth}s" [lindex $line 0] [lindex $line 1]]
  }
  append content "\n);"
  # Remove the last comma
  set index [string last {,} $content]
  set content [string replace $content $index $index {}]

  return $content
}

# ##############################################################
# Generates a VHDL instantiation template for the specified
# module.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vhdlTemplate {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # VHDL template

  # Categories: xilinxtclstore, designutils

  variable module
  variable inputBitPorts
  variable inputBusPorts
  variable outputBitPorts
  variable outputBusPorts
  variable inoutBitPorts
  variable inoutBusPorts

  set lines [list]
  # Process input single bit ports
  lappend lines "-- Input Ports - Single Bit"
  foreach port [lsort -dictionary $inputBitPorts] {
    lappend lines [list $port $port,]
  }
  # Process input bus ports
  lappend lines "-- Input Ports - Busses"
  foreach {port busInfo} [array2sortedList inputBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "${port}($start downto $stop)" "${port}($start downto $stop),"]
    } else {
      lappend lines [list "${port}($start to $stop)" "${port}($start to $stop),"]
    }
  }
  # Process output single bit ports
  lappend lines "-- Output Ports - Single Bit"
  foreach port [lsort -dictionary $outputBitPorts] {
    lappend lines [list $port $port,]
  }
  # Process output bus ports
  lappend lines "-- Output Ports - Busses"
  foreach {port busInfo} [array2sortedList outputBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "${port}($start downto $stop)" "${port}($start downto $stop),"]
    } else {
      lappend lines [list "${port}($start to $stop)" "${port}($start to $stop),"]
    }
  }
  # Process inout single bit ports
  lappend lines "-- InOut Ports - Single Bit"
  foreach port [lsort -dictionary $inoutBitPorts] {
    lappend lines [list $port $port,]
  }
  # Process inout bus ports
  lappend lines "-- InOut Ports - Busses"
  foreach {port busInfo} [array2sortedList inoutBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "${port}($start downto $stop)" "${port}($start downto $stop),"]
    } else {
      lappend lines [list "${port}($start to $stop)" "${port}($start to $stop),"]
    }
  }

  # Detect maximum column width to align columns
  foreach line $lines {
    if {[regexp {^\s*\-\-} $line]} {
      # Skip lines that are just comments
      continue
    }
    set width [string length [lindex $line 0]]
    if {![info exist maxWidth] || $maxWidth < $width} {
      set maxWidth $width
    }
  }

  # Build the content of the template:
  # Construct Formatted lines to align columns and print each line to output file
  set content "${module}_inst: ${module}"
  append content "\n   port map ("
  foreach line $lines {
    if {[regexp {^\s*\-\-} $line]} {
      # Lines that are just comments
      append content "\n      $line"
      continue
    }
    append content [format "\n      %-${maxWidth}s => %-${maxWidth}s" [lindex $line 0] [lindex $line 1]]
  }
  append content "\n   );"
  # Remove the last comma
  set index [string last {,} $content]
  set content [string replace $content $index $index {}]

  return $content
}

# ##############################################################
# Generates a Verilog blackbox entity declaration for the specified
# module.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vlogStub {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # Verilog stub

  # Categories: xilinxtclstore, designutils

  variable module
  variable inputBitPorts
  variable inputBusPorts
  variable outputBitPorts
  variable outputBusPorts
  variable inoutBitPorts
  variable inoutBusPorts

  set lines [list]
  # Process input single bit ports
  lappend lines "\/\/ Input Ports - Single Bit"
  foreach port [lsort -dictionary $inputBitPorts] {
    lappend lines "input  $port,"
  }
  # Process input bus ports
  lappend lines "\/\/ Input Ports - Busses"
  foreach {port busInfo} [array2sortedList inputBusPorts] {
    lassign $busInfo width stop start
    lappend lines "input  $port\[$start:$stop\],"
  }
  # Process output single bit ports
  lappend lines "\/\/ Output Ports - Single Bit"
  foreach port [lsort -dictionary $outputBitPorts] {
     lappend lines "output $port,"
  }
  # Process output bus ports
  lappend lines "\/\/ Output Ports - Busses"
  foreach {port busInfo} [array2sortedList outputBusPorts] {
    lassign $busInfo width stop start
    lappend lines "output $port\[$start:$stop\],"
  }
  # Process inout single bit ports
  lappend lines "\/\/ InOut Ports - Single Bit"
  foreach port [lsort -dictionary $inoutBitPorts] {
    lappend lines "inout  $port,"
  }
  # Process inout bus ports
  lappend lines "\/\/ InOut Ports - Busses"
  foreach {port busInfo} [array2sortedList inoutBusPorts] {
    lassign $busInfo width stop start
    lappend lines "inout  $port\[$start:$stop\],"
  }

  # Build the content of the stub:
  set content "module $module\("
  foreach line $lines {
    append content "\n   $line"
  }
  append content "\n\);"
  # Remove the last comma
  set index [string last {,} $content]
  set content [string replace $content $index $index {}]

  return $content
}

# ##############################################################
# Generates a VHDL blackbox entity declaration for the specified
# module.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vhdlStub {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # VHDL stub

  # Categories: xilinxtclstore, designutils

  variable module
  variable inputBitPorts
  variable inputBusPorts
  variable outputBitPorts
  variable outputBusPorts
  variable inoutBitPorts
  variable inoutBusPorts

  set lines [list]
  # Process input single bit ports
  lappend lines "-- Input Ports - Single Bit"
  foreach port [lsort -dictionary $inputBitPorts] {
    lappend lines [list "$port" "in  std_logic;"]
  }
  # Process input bus ports
  lappend lines "-- Input Ports - Busses"
  foreach {port busInfo} [array2sortedList inputBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "$port" "in  std_logic_vector($start downto $stop);"]
    } else {
      lappend lines [list "$port" "in  std_logic_vector($start to $stop);"]
    }
  }
  # Process output single bit ports
  lappend lines "-- Output Ports - Single Bit"
  foreach port [lsort -dictionary $outputBitPorts] {
    lappend lines [list "$port" "out  std_logic;"]
  }
  # Process output bus ports
  lappend lines "-- Output Ports - Busses"
  foreach {port busInfo} [array2sortedList outputBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "$port"  "out  std_logic_vector($start downto $stop);"]
    } else {
      lappend lines [list "$port" "out  std_logic_vector($start to $stop);"]
    }
  }
  # Process inout single bit ports
  lappend lines "-- InOut Ports - Single Bit"
  foreach port [lsort -dictionary $inoutBitPorts] {
    lappend lines [list "$port" "inout  std_logic;"]
  }
  # Process inout bus ports
  lappend lines "-- InOut Ports - Busses"
  foreach {port busInfo} [array2sortedList inoutBusPorts] {
    lassign $busInfo width stop start
    if {$start>$stop} {
      lappend lines [list "$port" "inout  std_logic_vector($start downto $stop);"]
    } else {
      lappend lines [list "$port" "inout  std_logic_vector($start to $stop);"]
    }
  }

  # Detect maximum column width to align columns
  foreach line $lines {
    if {[regexp {^\s*\-\-} $line]} {
      # Skip lines that are just comments
      continue
    }
    set width [string length [lindex $line 0]]
    if {![info exist maxWidth] || $maxWidth < $width} {
      set maxWidth $width
    }
  }

  # Build the content of the stub:
  set content {}
  foreach line $lines {
    if {[regexp {^\s*\-\-} $line]} {
      # Lines that are just comments
      append content "\n      $line"
      continue
    }
    append content [format "\n      %-${maxWidth}s :  %-${maxWidth}s" [lindex $line 0] [lindex $line 1]]
  }
  # Remove the last semi-colon
  set index [string last {;} $content]
  set content [string replace $content $index $index {}]
  # Now that the last semi-colon is replaced, add the header and footer
  set content [format "library IEEE;
use IEEE.std_logic_1164.all;
entity ${module} is
   port (%s
   );
end entity ${module};" $content]

  return $content
}

# ##############################################################
# Generates a Verilog testbench for specified module
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vlogTestBench {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # Verilog testbench

  # Categories: xilinxtclstore, designutils

   puts "This feature is not yet implemented"
   return {}
}

# ##############################################################
# Generates a VHDL testbench for specified module
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::vhdlTestBench {} {
  # Summary :

  # Argument Usage:

  # Return Value:
  # VHDL testbench

  # Categories: xilinxtclstore, designutils

   puts "This feature is not yet implemented"
   return {}
}

# ##############################################################
# Sort list of pins into busses and bit ports by removing
# hiearchical prefixes, and assigns them to the specified
# array and list, respectively.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::sortPins { pins &bus &bit } {
  # Summary : sort list of pins into busses and bit ports by removing hiearchical
  # prefixes, and assigns them to the specified array and list, respectively

  # Argument Usage:
  # pins :
  # &bus :
  # &bit :

  # Return Value:
  # 0

  # Categories: xilinxtclstore, designutils

   upvar ${&bus} busPorts
   upvar ${&bit} bitPorts
   array set busPorts [list ]
   set bitPorts [list]

   foreach pin $pins {
      set busName [get_property -quiet BUS_NAME [get_pins $pin]]
      if {![info exist busPorts($busName)] && [llength $busName]} {
         set busWidth [get_property -quiet BUS_WIDTH [get_pins $pin]]
         set busStart [get_property -quiet BUS_START [get_pins $pin]]
         set busStop  [get_property -quiet BUS_STOP  [get_pins $pin]]
         array set busPorts [list $busName [list $busWidth $busStop $busStart]]
      } elseif {[llength $busName] == 0} {
         lappend bitPorts [get_property -quiet REF_PIN_NAME $pin]
      }
   }
   return 0
}

# ##############################################################
# Sort list of ports into busses and bit ports, and assigns
# them to the specified array and list, respectively.
# ##############################################################
proc ::tclapp::xilinx::designutils::write_template::sortPorts { ports &bus &bit } {
  # Summary : sort list of ports into busses and bit ports, and assigns
  # them to the specified array and list, respectively

  # Argument Usage:
  # ports :
  # &bus :
  # &bit :

  # Return Value:
  # 0

  # Categories: xilinxtclstore, designutils

  upvar ${&bus} busPorts
  upvar ${&bit} bitPorts
  array set busPorts [list ]
  set bitPorts [list]

  foreach port $ports {
    set busName [get_property -quiet BUS_NAME [get_ports $port]]
    if {![info exist busPorts($busName)] && [llength $busName]} {
      set busWidth [get_property -quiet BUS_WIDTH [get_ports $port]]
      set busStart [get_property -quiet BUS_START [get_ports $port]]
      set busStop  [get_property -quiet BUS_STOP  [get_ports $port]]
      array set busPorts [list $busName [list $busWidth $busStop $busStart]]
    } elseif {[llength $busName] == 0} {
      lappend bitPorts $port
    }
  }
  return 0
}

proc ::tclapp::xilinx::designutils::write_template::array2sortedList { &ar } {
  # Summary : convert an array into a sorted list

  # Argument Usage:
  # &ar : Array passed by reference

  # Return Value:
  # sorted list

  # Categories: xilinxtclstore, designutils

  upvar ${&ar} ar
  set sortedList [list]
  foreach key [lsort -dictionary [array names ar]] {
    lappend sortedList $key
    lappend sortedList $ar($key)
  }
  return $sortedList
}

proc ::tclapp::xilinx::designutils::write_template::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}
