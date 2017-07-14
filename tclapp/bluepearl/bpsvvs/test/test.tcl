set path [file dirname [info script]]
puts "script is invoked from $path"
source [file join $path bpsvvs_0001.tcl]
source [file join $path bpsvvs_0002.tcl]
