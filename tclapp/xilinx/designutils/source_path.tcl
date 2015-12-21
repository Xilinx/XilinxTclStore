package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export source_path
}

proc ::tclapp::xilinx::designutils::source_path {script search_path} {
  # Summary : Source a script from a choice of paths

  # Argument Usage:
  # script : Name of file to source
  # search_path : Ordered list of directories to find the script

  # Return Value:
  # 0 on success
  # TCL_ERROR if script could not be found
  
  # Categories: xilinxtclstore, designutils

  foreach dir $search_path {
    if {[file exists $dir/$script]} {
      puts "Sourcing [file normalize $dir/$script]" 
      source -notrace $dir/$script
      return 0
    }
  }
  error " error - couldn't find file \"$script\" in search path \"$search_path\""
}
