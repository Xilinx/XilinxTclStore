# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded ::tclapp::aldec::common::helpers 1.39 [list source [file join $dir helpers.tcl]]
package ifneeded ::tclapp::aldec::common::sim 1.39 [list source [file join $dir sim.tcl]]
