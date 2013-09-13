####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

package require ::tclapp::xilinx::designutils 1.0

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_pid_mem get_mem
}

proc ::tclapp::xilinx::designutils::get_mem {} {
  # Summary : queries the kernel for current heap memory of Vivado session

  # Argument Usage:
  # None

  # Return Value:
  # the amount of heap memory
  
  return [::tclapp::xilinx::designutils::get_pid_mem [uplevel #0 pid]]
}


proc ::tclapp::xilinx::designutils::get_pid_mem { {pid {}} } {
  # Summary : queries the kernel for current heap memory

  # Argument Usage:
  # pid : process id

  # Return Value:
  # the amount of heap memory
  
  set mem {}
  if {$pid == {}} { set pid [uplevel #0 pid] }
  if {$pid != ""} {
    if {[::tclapp::xilinx::designutils::get_host_platform] == {windows}} {
      # handle windows kernel call
      # Sample string to be parsed:
      #   Image Name                     PID Session Name        Session#    Mem Usage
      #   ========================= ======== ================ =========== ============
      #   PDF Copy-Paster.exe           8812 Console                    1     10,016 K
      #
      # => Return: 10,016 K
      set mem [lrange [lindex [split [exec tasklist /FI "PID eq $pid"] \n] end] end-1 end]
    } else {
      # handle linux/unix kernel call through the ps command
      # RSS - Resident Set Size - is the best memory metric we have, it's the 18th field returned from ps
      set mem [lindex [exec ps v -p $pid] 17]
    }
  }
  return $mem
}

