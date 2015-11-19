####################################################################################
#
# communication.tcl (helper utilities for tk_tunnel)
#
# Script created on 11/20/2012 by Nik Cimino (Xilinx, Inc.)
#
# 2012 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################

#
# Getting Started:
#     % package require ::tclapp::xilinx::tk_tunnel
#     % ::tclapp::xilinx::tk_tunnel::launch_server "/usr/bin/tclsh8.5"
#     % ::tclapp::xilinx::tk_tunnel::start_client
#     % ::tclapp::xilinx::tk_tunnel::rexec { tk::toplevel .w; wm title .w "New Window"; }
#

catch { package require Vivado 1.2014.1 } _packageRequireOutput

namespace eval ::tclapp::xilinx::tk_tunnel {

# Export procs that should be allowed for import into other namespaces
# Client
namespace export wait
namespace export rexec
namespace export rexec_wait
namespace export start_client
namespace export launch_server
namespace export wait_for_response
namespace export connect_to_server
# Server
namespace export broadcast
namespace export stdin_event
namespace export socket_event
namespace export start_server
namespace export exec_push_return
namespace export accept_connection


variable sock {}
variable local_wait_on 0
variable dbg 1
variable client_return {}
variable server_return {}
variable connected_clients {}

proc rexec {cmd} {

  # Summary : Executes a command on the Tk server (remote exec)
  # User / Client command

  # Argument Usage:
  # cmd : The command you would like to execute on the server

  # Return Value: 
  # TCL_OK is returned if the procedure completed

  # Categories: xilinxtclstore, tk_tunnel

  variable sock
  puts $sock "${cmd}"
  return 0
}

proc rexec_wait {cmd} {

  # Summary : Executes a command on the Tk server (remote exec), and waits for the response/return
  # User / Client command

  # Argument Usage:
  # cmd : The command you would like to execute on the server

  # Return Value: 
  # The return value of the executed command

  # Categories: xilinxtclstore, tk_tunnel

  variable sock
  set ::tclapp::xilinx::tk_tunnel::client_return {}
  puts $sock "::tclapp::xilinx::tk_tunnel::exec_push_return {$cmd}"
  return [::tclapp::xilinx::tk_tunnel::wait_for_response]
}

proc exec_push_return {cmd} {

  # Summary : Executes a command locally and broadcasts the return to the client (called by rexec_wait)
  # Tk / Server command

  # Argument Usage:
  # cmd : The command to be executed, the server_return will be sent to the client as client_return

  # Return Value: 
  # The return value of the executed command

  # Categories: xilinxtclstore, tk_tunnel

  set ::tclapp::xilinx::tk_tunnel::server_return {}
  catch {eval $cmd} ::tclapp::xilinx::tk_tunnel::server_return
  ::tclapp::xilinx::tk_tunnel::broadcast "set ::tclapp::xilinx::tk_tunnel::client_return {$::tclapp::xilinx::tk_tunnel::server_return}"
  return $::tclapp::xilinx::tk_tunnel::server_return
}

proc wait_for_response {} {

  # Summary : Waits for client_return to be set (called by rexec_wait)
  # Tk / Client command

  # Argument Usage:
  # none

  # Return Value: 
  # The client_return value is returned after it has been set

  # Categories: xilinxtclstore, tk_tunnel

  puts "waiting for response..."
  vwait ::tclapp::xilinx::tk_tunnel::client_return
  return $::tclapp::xilinx::tk_tunnel::client_return
}

proc start_client {{host "127.0.0.1"} {port 8001}} {

  # Summary : Starts the client that will be sending the Tk commands
  # User / Client command

  # Argument Usage:
  # [host=127.0.0.1] : This specifies the host (server) that the client will try to connect to
  # [port=8001] : This specifies the (server) port that the client will try to connect to

  # Return Value: 
  # The client_return value is returned after it has been set

  # Categories: xilinxtclstore, tk_tunnel

  variable sock
  set sock [::tclapp::xilinx::tk_tunnel::connect_to_server $host $port]
  fileevent $sock readable [list ::tclapp::xilinx::tk_tunnel::socket_event $sock]
  fconfigure $sock -buffering line
  puts "client listeners are now running"
}

proc launch_server {{tclsh "tclsh"} {server_file {}}} {

  # Summary : Starts the server that the Tk commands will be sent to (launched from client)
  # The user can bypass calling this proc and launch the server with a custom command, like:
  # exec xterm -iconic -e /usr/local/tclsh ./custom_start_server.tcl &
  # User / Client command

  # Argument Usage:
  # [tclsh_path=tclsh] : This specifies the tclsh command or path to a Tcl/Tk 8.5 shell
  # [server_file=$XILINX_TCLAPP_REPO/xilinx/tk_tunnel/start_server.tcl] : This specifies the 
  # tcl file used to launch the server, by default it points to a general purpose script

  # Return Value: 
  # The command launch return value is returned

  # Categories: xilinxtclstore, tk_tunnel

  set thisFile [ dict get [ info frame [ info frame ] ] file ]
  if { $server_file == {} } {
    set server_file [ file normalize [ file join [ file dirname $thisFile ] "server" "start.tcl" ] ]
  }
  if { ! [ file exists $server_file ] } {
    error "Unable to locate server start script: '${server_file}'"
  }

  set tclsh_path [ auto_execok $tclsh ] 
  if { "${tclsh_path}" == "" } {
    error "Unable to find tclsh using '${tclsh}'. Ensure the Tcl shell path exists, or try specifying the path:\n\tlaunch_server <Tcl Shell Path> <Server Launch Script>"
  }

  if { $::tcl_platform(platform) == "windows" } {
    set shellCmd "cmd.exe"
  } else {
    set shellCmd "xterm"
  }

  set shellCmdPath [ auto_execok $shellCmd ]
  if { "${shellCmdPath}" == "" } {
    error "Detected environment \[tcl_platform(platform)\] '$::tcl_platform(platform)', and failed to locate '${shellCmd}'"
  }

  puts "Attempting to launch server...\n  Server Launch Script:\n    '${server_file}'\n  Tcl Shell Path:\n    '${tclsh_path}'"
  if { $::tcl_platform(platform) == "windows" } {
    #exec {*}[auto_execok start] {} "cmd /k $tclsh_path $server_file" &
    return [exec $shellCmdPath /c start cmd /c $tclsh_path $server_file &]
  } else {
    #return [exec $shellCmdPath -iconic -e $tclsh_path $server_file &]
    return [exec $shellCmdPath -e $tclsh_path $server_file &]
  }
}

proc socket_event {sock} {

  # Summary:
  # This proc is called when a socket event occurs
  # Tk / Client command

  # Argument Usage: 
  # sock : Is the socket of the event

  # Return Value:
  # return_value - Returns the return value of the executed command

  # Categories: xilinxtclstore, tk_tunnel

  variable connected_clients
  variable local_wait_on
  set command [gets $sock]
  # puts "socket event"
  if { [eof $sock] } {
    close $sock
    set hit [lsearch $connected_clients $sock]
    if { $hit != -1 } {
      set connected_clients [lreplace $connected_clients $hit $hit]
    }
    set ::tclapp::xilinx::tk_tunnel::client_return "disconnected"
    puts "disconnected"
    set local_wait_on "done" 
  } else {
    if { [catch [list eval $command] return_value] } {
      puts "error occurred while executing '$command'\n\treturned '$return_value'"
    } else {
      puts "executed: ${command}\n\treturned: '$return_value'"
    }
  }
}

proc stdin_event {sock} {

  # Summary:
  # This proc is called when a stdin event occurs
  # Tk / Server command

  # Argument Usage: 
  # sock : Is the socket to close when CTRL+D (eof) is encountered on stdin

  # Return Value:
  # input - Returns the stdin value

  # Categories: xilinxtclstore, tk_tunnel

  variable local_wait_on
  set input [gets stdin]
  if { [eof stdin] } {
    close $sock
    set local_wait_on "done" 
  }
  ::tclapp::xilinx::tk_tunnel::broadcast $input
  return $input
}

proc connect_to_server {host port} {

  # Summary:
  # This proc is called to connect a client to a server, it will wait until it is connected
  # Tk / Client command

  # Argument Usage: 
  # host : This specifies the host (server) that the client will try to connect to
  # port : This specifies the (server) port that the client will try to connect to

  # Return Value:
  # socket - Returns the client-side socket 

  # Categories: xilinxtclstore, tk_tunnel

  puts -nonewline "connecting to server on port: '${port}'\n\twaiting on server..."
  set i 0
  while { [catch {socket $host $port} sock] } { 
    incr i
    puts -nonewline "."
    if { $i > 20 } { error "timed out - server is unreachable" }
    wait
  }
  fconfigure $sock -buffering line
  puts "connected"
  return $sock
}

proc accept_connection {sock addr port} {

  # Summary:
  # This proc is the callback function when the server receives a connection request
  # Tk / Server command

  # Argument Usage: 
  # sock : This specifies the socket of the connection to the client
  # addr : This specifies the addr of the client 
  # port : This specifies the port of the client

  # Return Value:
  # true - Returns true or throw an error

  # Categories: xilinxtclstore, tk_tunnel

  variable connected_clients
  fileevent $sock readable [list ::tclapp::xilinx::tk_tunnel::socket_event $sock]
  lappend connected_clients $sock
  fconfigure $sock -buffering line
  set connect_time [clock format [clock seconds]]
  puts "accepted connection from $addr:$port at $connect_time"
  return 1
}

proc start_server {{port 8001}} {

  # Summary:
  # This command launches the listening service on the server
  # User / Server command (normally called from the start_server.tcl script)

  # Argument Usage: 
  # [port=8001] : This specifies the port of the server

  # Return Value:
  # server - Returns server socket object (not very useful)

  # Categories: xilinxtclstore, tk_tunnel

  set hostname   [info hostname]
  set server     [socket -server ::tclapp::xilinx::tk_tunnel::accept_connection $port]
  set ip       [lindex [fconfigure $server -sockname] 0]
  puts "server starting - host: $hostname - ip: $ip - socket: $server"

  fileevent stdin readable [list ::tclapp::xilinx::tk_tunnel::stdin_event $server]
  puts "server listeners are now running"
  hide_server_start

  return $server
}

proc broadcast {input} {

  # Summary:
  # This command broadcasts a command / response to all clients from the server
  # Tk / Server command

  # Argument Usage: 
  # input : This specifies the command / response to broadcast

  # Return Value:
  # input - Returns what the input was

  # Categories: xilinxtclstore, tk_tunnel

  variable connected_clients
  puts "broadcasting: $input"
  foreach client $connected_clients {
    puts "\tto: $client"
    puts $client $input
  }
  return $input
}

# private

proc wait {{time {500}}} {

  # Summary:
  # This proc will wait for a specified time
  # Tk / Client command

  # Argument Usage: 
  # [time=500] : This specifies the time in ms

  # Return Value:
  # time - Returns the time waited in ms

  # Categories: xilinxtclstore, tk_tunnel

  set wait_on {}
  after $time { set wait_on "next" }
  vwait wait_on
  return $time
}

}; # end namespace ::tclapp::xilinx::tk_tunnel
