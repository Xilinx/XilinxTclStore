set appName {xilinx::tk_tunnel}
  
set listInstalledApps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}
  
# Start the unit tests
puts "script is invoked from $test_dir"

if { [ info exists ::env(RDI_DEVKIT) ] } {
  # e.g. linux>lnx unix>lnx nt>win windows>win
  if { "$::tcl_platform(platform)" == "unix" } {
    set os "lnx"
  } else {
    set os "win"
  }
  # e.g. 32 64 128...
  set bits_in_word 8
  set architecture [expr "$::tcl_platform(wordSize)*${bits_in_word}"]
  # e.g. win32 win64 lnx32 lnx64 lnx24
  set platform "${os}${architecture}"
  set launch_shell [ file join $::env(RDI_DEVKIT) $platform "tcl-8.5.14" "bin" "tclsh8.5" ]
} else {
  set launch_shell "tclsh85"
}

set server_file [ file normalize [ file join $test_dir ".." "server" "start.tcl" ] ]

set procid [ ::tclapp::xilinx::tk_tunnel::launch_server $launch_shell $server_file ]

::tclapp::xilinx::tk_tunnel::start_client

# Asynchronous : broadcasts from client using server back to client and sets global variable a to 1
# 1) rexec sends command to server
# 2) broadcast is executed on server which sends command to all clients
# 3) set ::a 1 is sent to and executed on client
puts "Having the server set clients \$::tclapp::xilinx::tk_tunnel::a = 1"
::tclapp::xilinx::tk_tunnel::rexec {::tclapp::xilinx::tk_tunnel::broadcast {set ::tclapp::xilinx::tk_tunnel::a 1}}
::tclapp::xilinx::tk_tunnel::wait; # 500 ms

puts "The clients \$::tclapp::xilinx::tk_tunnel::a = "
::tclapp::xilinx::tk_tunnel::rexec {::tclapp::xilinx::tk_tunnel::broadcast {puts $::tclapp::xilinx::tk_tunnel::a}}
::tclapp::xilinx::tk_tunnel::wait; # 500 ms

puts "Puts \$::tclapp::xilinx::tk_tunnel::a = $::tclapp::xilinx::tk_tunnel::a"

if { $::tclapp::xilinx::tk_tunnel::a != 1 } {
  error "sent from client to server a broadcast command that should have set \$::tclapp::xilinx::tk_tunnel::a to 1, instead found: '$::tclapp::xilinx::tk_tunnel::a'"
}

# Synchronous : tells the server to execute 'return 2' and client to wait for the response
set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {return 2}]
puts "Answer: $answer"
set expected 2


if { $answer != $expected } {
  error "rexec_wait did not return the expected value '${expected}', instead found '${answer}'"
}

# Synchronous : tells the server to ask and wait for the response
#set answer2 [rexec_wait {ask "Are you having fun?"}]
#puts "Answer2: $answer2"
# Disabled: cannot have interactive for auto testing

if { $::tcl_platform(platform) == "unix" } {
  exec [ auto_execok kill ] -9 $procid
} else {
  exec [ auto_execok taskkill ] /F /PID $procid
}

puts "Done. Success."

