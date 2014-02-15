set path [file dirname [info script]]
puts "script is invoked from $path"
source [file join $path xsim_0001.tcl]
