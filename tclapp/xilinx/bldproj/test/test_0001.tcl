set file_dir [file dirname [info script]]

puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

package require ::tclapp::xilinx::bldproj
namespace import ::tclapp::xilinx::bldproj::*

puts "Testing bldproj"
