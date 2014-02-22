package require ::tclapp::xilinx::designutils
set path [file normalize [file dirname [info script]]]
puts "script is invoked from $path"
source [file join $path write_slr_pblock_xdc_0001.tcl]
