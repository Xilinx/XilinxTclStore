####################################################################################
#
# populate_sim_repo.tcl
#
# Script created on 05/20/2015 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export populate_sim_repo
}

namespace eval ::tclapp::xilinx::projutils {

proc populate_sim_repo {args} {
  # Summary:
  # populate_sim_repo is not supported anymore, please use 'export_ip_user_files'
  # Argument Usage:
  # [-of_objects <arg>]: IP,IPI or a fileset
  # [-ip_user_files_dir <arg>]: Directory path to simulation base directory (for dynamic and other IP non static files)
  # [-ipstatic_source_dir <arg>]: Directory path to the static IP files
  # [-no_script]: Do not export simulation scripts
  # [-clean_dir]: Delete all IP files from central directory
  # [-force]: Overwrite files 

  # Return Value:
  # list of files that were populated

  # Categories: simulation, xilinxtclstore

  send_msg_id populate_sim_repo-Tcl-001 WARNING "This command is not supported anymore. Please type or update your scripts with 'export_ip_user_files' instead. For more information please type 'export_ip_user_files' -help.\n"
  return
}
}
