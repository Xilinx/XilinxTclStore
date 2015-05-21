
##########################################################################################
# Purpose: Add net to port as a probe
# Revision: Initial Version, designed and verified on Vivado 2014.4
###########################################################################################
package require Vivado 1.2014.4

namespace eval ::tclapp::xilinx::debugutils {
    # Export procs that should be allowed to import into other namespaces
    namespace export add_probe
}

proc ::tclapp::xilinx::debugutils::lflatten {data} {
  # Summary :
  # Argument Usage:
  # Return Value:

  while { $data != [set data [join $data]] } { }
  return $data
}

proc ::tclapp::xilinx::debugutils::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

proc ::tclapp::xilinx::debugutils::add_probe {args} {

  # Summary : Connect net signal to port as a probe
	
  # Argument Usage:
  # -net <netName> : The internal net you want to add to probe
  # -loc <packagePin> : The FPGA package pin used as the probe
  # -iostandard <iostandard> : Set IOStandard for the probe port
  # -port <portName> : Give the probe port a name
  # -usage|-u : Help message

  # Return Value:
  # Selected signal was connected to slected port and finished routing, If any error occur an error information is returned

  # Categories: xilinxtclstore, debugutils

  set error 0
  set help 0
  set signal  {}
  set pin {}
  set IOStandard {LVCMOS18}
  set name {}
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set option [lshift args]
    switch -exact -- $option {
      -net -
      -net {
           set signal [lflatten [lshift args]]
      }
      -loc  -
      -loc  {
           set pin [lshift  args]
      }
      -port -
      -port {
           set name [lshift args]
      }
      -iostandard -
      -iostandard {
           set IOStandard [lshift args]
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $option]} {
              puts " -E- option '$option' is not a valid option."
              incr error
            } else {
              puts " -E- option '$option' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: add_probe
              [-net <netName>]            - Internal net to probe
              [-port <portName>]          - Output port name
              [-loc <packagePin>]         - FPGA package pin to use for the probe
              [-iostandard <iostandard>]  - IOSTANDARD for probe port
              [-usage|-u]                 - This help message

  Description: Add probe to the design and connect the probe to an output port

  Only add one probe at each time.
  the probe port can be existed or not, but if port alreay exist, please use exactly same pin loc & iostandard.
  When any error happened, will report critical warnings.

  It is recommended to use the command on an unplaced design.

  Example:
     add_probe -net cpuEngine/or1200_cpu/p_0_in[10] -port myprobe -iostandard HSTL -loc W26
} ]
    # HELP -->
    return -code ok
  }

  if {$signal ==  {}} {
    puts " -E- use -net to define a net"
    incr error
  } else {
    set net [get_nets -quiet $signal]
    switch [llength $net] {
      0 {
        puts " -E- net '$signal' does not exists"
        incr error
      }
      1 {
        # OK
      }
      default {
        puts " -E- net '$signal' matches  multiple nets"
        incr error
      }
    }
  }

  if {$name == {}} {
    puts " -E- use -port to define an output  port"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  puts "Calling ::tclapp::xilinx::debugutils::add_probe"
  puts " Net         : $signal"
  puts " Port        : $name"
  puts " Package Pin : $pin"
  puts " IOStandard  : $IOStandard"
  
  # identify if selected signal could be added to port as a probe
  set route_status [get_property ROUTE_STATUS [get_nets $signal]]
  if {$route_status == "INTRASITE"} {
    error "Critical Warning:  Cannot add a probe to the selected net, because it only exists inside of the SLICE."
  }
  # identify if assigned port name exists but is not an output port or has different pin loc.
  if {[llength [get_ports -quiet $name]] != 0 } {
    set port_exist 1
    set port_direction [get_property DIRECTION [get_ports $name]]
    set port_package [get_property PACKAGE_PIN [get_ports $name]]
    if {$port_direction != "OUT"} {
      error "Critical Warning:  Port with assigned name already exists but it's not an output port, please correct."
    } elseif {$port_package != $pin } {
      error "Critical Warning:  Port with assigned name already exists but it's name doesn't match location, please correct."
    }
  # identify if assigned port loc exists but is not an output port or has different pin name. 
  } elseif {[llength [get_ports -quiet -filter "PACKAGE_PIN == $pin"]] != 0 } {
    set port_exist 1
    set port_direction [get_property DIRECTION  [get_ports -filter "PACKAGE_PIN == $pin"]]
    set port_name [get_property NAME  [get_ports -filter "PACKAGE_PIN == $pin"]]
    if {$port_direction != "OUT"} {
      error "Critical Warning:  Port with assigned package pin already exists but it's not an output port, please correct."
    } elseif {$port_name != $name } {
      error "Critical Warning:  Port with assigned package pin already exists but its location doesn't match name, please correct."
    }
  } else {
    set port_exist 0
  }

  # get placed cells drive the net to be debugged
  set cells_to_unplace [get_cells -of [get_pins -leaf -filter {DIRECTION == OUT} -of  [get_nets -segments $signal]]]
  # save the LOCs of the placed cells
  foreach cell $cells_to_unplace {
     set cell_loc($cell) [get_property LOC $cell]
     set cell_bel($cell) [get_property BEL $cell]
  # identify if cells attached with net to be debugged have been placed or not  
     if {$cell_loc($cell) == "" || $cell_bel($cell) == "" } {
		error "Critical Warning: Cells attached to selected net haven't been placed or have been unplaced before, please use fully placed and routed netlist."  
	 }
  }

  # identify if port name exists or not, then create the port and/or attach OBUF.
  if {$port_exist == 0} {
    puts "Note: Port doesn't exist, create it first."
    set obuf_name $name\_obuf
    create_port -direction OUT $name
    create_cell -reference OBUF $obuf_name
    create_net  $obuf_name\_net
    connect_net -net [get_nets $obuf_name\_net] -objects "[get_pins $obuf_name/O] [get_ports $name]"
   } else {
      if {[llength [get_nets -quiet -segments -of [get_ports $name]]] == 0} {
        puts "Note: Port already exists, but doesn't connect to any signal. Attach it to debug signal."
        set obuf_name $name\_obuf
        create_cell -reference OBUF $obuf_name
        create_net  $obuf_name\_net
        connect_net -net [get_nets $obuf_name\_net] -objects "[get_pins $obuf_name/O] [get_ports $name]"
    } else {
        puts "Note: Port already exists, and connects to another signal. Change it to debug signal."
        set obuf_name [get_cells -filter {REF_NAME == OBUF} -of [get_pins -leaf -filter {DIRECTION == OUT} -of [get_nets -of [get_ports $name ]]]]
        set debug_net [get_nets -of [get_pins -filter {DIRECTION == IN} -of [get_cells $obuf_name]]]
        route_design -unroute -pin [get_pins $obuf_name/I]
        disconnect_net -net $debug_net -objects [get_pins $obuf_name/I]
    }
  }

  # connect net to be debugged to OBUF input
  connect_net -hier -net $signal -objects [get_pins $obuf_name/I]

  # set the debug probe I/O standards and package pin
  set_property IOSTANDARD $IOStandard [get_port $name]
  set_property PACKAGE_PIN $pin [get_port $name]

  # LOC the unplaced cells
  foreach cell $cells_to_unplace {
    place_cell $cell $cell_loc($cell)/$cell_bel($cell)
   }

  puts "Note: Selected signal has already been connected to probe port and is ready to be routed !"
  # route design incrementally
  #route_design -preserve
  route_design  -pin [get_pins $obuf_name/I]
  return -code ok
}

