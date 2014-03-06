package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export create_diff_ports
}

# Tcl procs to create differential ports from
# single-ended ports in a pinplanning project.

proc ::tclapp::xilinx::designutils::create_diff_ports {} {
  # Summary : Creates differential _N port for each _P port in a pinplanning design
  
  # Argument Usage:

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  uplevel ::tclapp::xilinx::designutils::create_diff_ports::create_diff_ports
  return 0
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::create_diff_ports { 
} ]

proc ::tclapp::xilinx::designutils::create_diff_ports::create_diff_ports {} {
  # Summary : Creates differential _N port for each _P port in a pinplanning design
  
  # Argument Usage:
  
  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  # For now, assume either _p or _P suffix designates a differential port
  # In the future, you could check iostandard or some other attribute
  # Also assumes busses are continuous (no skipping indexes)
  
  set busIndexMax [dict create]
  set busIndexMin [dict create]
  set baseNames [list]

  getPortNames baseNames busIndexMax busIndexMin
  foreach port $baseNames {
    if {[dict exists $busIndexMax $port]} {
      set idxMax [dict get $busIndexMax $port]
      set idxMin [dict get $busIndexMin $port]
      createDiffPort $port $idxMax $idxMin
    } else {
      createDiffPort $port
    }
  }
  return 0
}

proc ::tclapp::xilinx::designutils::create_diff_ports::createDiffPortScalar {port} {
  # Summary : Takes a port and creates its diff pair member

  # Argument Usage:
  # port : port, assumes the port suffix is _p, _P, or no suffix

  # Return Value:
  
  # Categories: xilinxtclstore, designutils

  # works for scalar ports only
  # not used by the top-level proc
  
  set dir [get_property -quiet DIRECTION [get_ports -quiet $port]]
  set baseName $port

  # name the N port based on the P port name
  if {[regexp .*_p$ $baseName]} {
    # ends in _p
    set portP $baseName
    regsub _p$ $portP _n portN
  } elseif {[regexp .*_P$ $baseName]} {
    # ends in _P
    set portP $baseName
    regsub _P$ $portP _N portN
  } elseif {[regexp {^[A-Z0-9]+$} $baseName]} {
    # all uppercase letters?
    set portP ${baseName}_P
    set portN ${baseName}_N
  } else {
    # no, some lowercase
    set portP ${baseName}_p
    set portN ${baseName}_n
  }

  # create the N ports, rename P ports with suffix if necessary
  # then designate as P/N pair
  create_port -direction $dir $portN
  if {$port != $portP} {
    set_property NAME $portP [get_ports -quiet $port]
  }
  make_diff_pair_ports $portP $portN
}


proc ::tclapp::xilinx::designutils::create_diff_ports::createDiffPort {port {idxMax {}} {idxMin {}} } {
  # Summary: Takes a port and creates its diff pair member

  # Argument Usage:
  # port : assumes the port suffix is _p, _P
  # [idMax = ] : max
  # [idMin = ] : min

  # Return Value:
  # none
  
  # works for scalars or busses if max and min indexes are supplied
  
  set dir [lindex [get_property -quiet DIRECTION [get_ports -quiet $port]] 0]
  # note: needed lindex 0 - returns multiple duplicate values for busses
  set baseName $port
  # name the N port based on the P port name
  if {[regexp .*_p$ $baseName]} {
    # ends in _p
    set portP $baseName
    regsub _p$ $portP _n portN
  } elseif {[regexp .*_P$ $baseName]} {
    # ends in _P
    set portP $baseName
    regsub _P$ $portP _N portN
    # for future expansion, currently names must end in _p or _P
  } elseif {[regexp {^[A-Z0-9]+$} $baseName]} {
    # all uppercase letters?
    set portP ${baseName}_P
    set portN ${baseName}_N
  } else {
    # no, some lowercase
    set portP ${baseName}_p
    set portN ${baseName}_n
  }

  # create the N ports, rename P ports with suffix if necessary
  # then designate as P/N pair
  if {$idxMax != $idxMin} {
    # bussed port
    create_port -direction $dir $portN -from $idxMin -to $idxMax
    for {set idx $idxMin} {$idx <= $idxMax} {incr idx} {
      if {$port != $portP} {
        set_property NAME $portP\[$idx\] [get_ports -quiet $port\[$idx\]]
      }
      make_diff_pair_ports $portP\[$idx\] $portN\[$idx\]
    }
  } else {
    # scalar port
    create_port -direction $dir $portN
    if {$port != $portP} {
      set_property NAME $portP [get_ports -quiet $port]
    }
    make_diff_pair_ports $portP $portN
  }

  # copy the P IOStandard if present
  set iostd [get_property -quiet IOSTANDARD [get_ports -quiet $portP]]
  if {$idxMax != $idxMin} { ; # it's a bus
    for {set idx $idxMin} {$idx < $idxMax} {incr idx} {
      set_property IOSTANDARD [lindex $iostd 0] [get_ports -quiet $portN[$idx]]
    }
  } elseif {[llength $iostd] == 1} { ; # it's a scalar port
    set_property IOSTANDARD $iostd [get_ports -quiet $portN]
  } else {
    puts "Could not automatically assign IOSTANDARD for $portN"
  }

  # Try to assign N LOC based on P if present
  if {$idxMax != $idxMin} { ; # it's a bus
    for {set idx $idxMin} {$idx < $idxMax} {incr idx} {
      # call getPairPin to get the N pin assignment
      set pinN [getPairPin $portP\[$idx\]]
      if {$pinN != {}} {
        set_property LOC $pinN [get_ports -quiet $portN\[$idx\]]
        puts "Assigned $portN\[$idx\] to site $pinN"
      } else {
        puts "Could not automatically assign site for $portN\[$idx\]"
      }
    }
  } else { ; # scalar port
    set pinN [getPairPin $portP]
    if {$pinN != {}} {
      set_property LOC $pinN [get_ports -quiet $portN]
      puts "Assigned $portN to site $pinN"
    } else {
      puts "Could not automatically assign site for $portN"
    }
  }
}

proc ::tclapp::xilinx::designutils::create_diff_ports::getPortNames {baseNames busIndexMax busIndexMin} {
  # Summary : This searches all ports for busses
  
  # Argument Usage:
  # baseNames   : base names
  # busIndexMax : max bus index
  # busIndexMin : min bus index
  
  # Return Value:
  # returns list of port names, maximum and minimum indexes for each bus
  
  # Categories: xilinxtclstore, designutils

  upvar baseNames ports
  upvar busIndexMax idxMax
  upvar busIndexMin idxMin

  foreach port [get_ports -quiet *] {
    # check if port is part of a bus: baseName[index]
    if {[regexp {(?i)(.*_p)\[(\d+)\]} $port isBussed baseName index]} {
      # add port to list of port names if not already in list
      if {[lsearch $ports $baseName] < 0} {
        lappend ports $baseName
      }
      if {[lsearch [dict keys $idxMax] $baseName] >= 0} {
        # bus exists in list of busses, check index against min/max
        if {$index > $idxMax} {
          dict set idxMax $baseName $index
        } elseif {$index < $idxMin} {
          dict set idxMin $baseName $index
        }
      } else {
        # bus not yet in list of busses, initialize min/max
        dict set idxMax $baseName $index
        dict set idxMin $baseName $index
      }
    } else {
      # scalar port
      if {[lsearch $ports $port] < 0} {
        lappend ports $port
      }
    }
  }
}


proc ::tclapp::xilinx::designutils::create_diff_ports::getPairPin {portP} {
  # Summary : Given the P port, do a "reverse lookup" of the corresponding N port if possible using the pin function
  
  # Argument Usage:
  # portP : a P port

  # Return Value:
  # corresponding N port
  
  # Categories: xilinxtclstore, designutils

  upvar pinFuncTable pinFuncs ; # emulate "static" variable
  if {![info exists pinFuncs]} {
    # create a table of sites and their I/O functions
    set pinFuncs [dict create]
    foreach pin [get_package_pins] {
      dict set pinFuncs $pin [get_property -quiet PIN_FUNC $pin]
    }
  }
  # get the pin, pin function
  set pinP [get_property -quiet LOC [get_ports -quiet $portP]]
  set pinN {}
  if {$pinP != {}} {
    set pinFuncP [dict get $pinFuncs $pinP]
    # see if there is a corresponding N pin function
    # for example if the P is on IO_L2P_T0_39 what pin matches IO_L2N_T0_39
    # The regexp used below is weak and can be improved to increase matches.
    regexp {(.*L\d+)P(.*)} $pinFuncP x str1 str2
    set pinFuncN ${str1}N$str2
    # reverse-lookup the N pin function to get the pin site
    set pinN [lindex $pinFuncs [expr [lsearch -regexp $pinFuncs $pinFuncN] - 1]]
  } else {
    puts "Port $portP does not have a pin assignment"
  }
  return $pinN
}

