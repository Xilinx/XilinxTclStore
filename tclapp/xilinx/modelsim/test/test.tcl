set path [file dirname [info script]]
puts "script is invoked from $path"
source [file join $path modelsim_0001.tcl]
