# Xilinx Tk Tunnel App

This app can be used to launch a Tcl/Tk 8.5 server in a remote shell, and pass commands
from Vivado to the Tk shell.  This enables Tk like behavior from Vivado.

_Notice_: Version 1.6 or later should be used due to known issues.

## Getting Started

### Require the package:

    Vivado% package require ::tclapp::xilinx::tk_tunnel
    
    1.6

### Start the server:

_Note_: This command launches a remote shell with Tcl running in it, and it returns the PID of that remote shell

    Vivado% ::tclapp::xilinx::tk_tunnel::launch_server "/opt/tcl/bin/tclsh8.5"
    
    Attempting to launch server...
      Server Launch Script:
        '/home/ncimino/XilinxTclStore/tclapp/xilinx/tk_tunnel/server/start.tcl'
      Tcl Shell Path:
        '/opt/tcl/bin/tclsh8.5'
    2865
    
### Connect Vivado to the remote Tcl shell:

    Vivado% ::tclapp::xilinx::tk_tunnel::start_client
    
    connecting to server on port: '8001'
            waiting on server...connected
    client listeners are now running

### Send a Tk command to the remote Tcl shell:

    Vivado% set response [ ::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Are you having fun?"} ]
    
    waiting for response...
    yes
    executed: puts stdout {yes}
            returned: ''
    executed: set ::tclapp::xilinx::tk_tunnel::client_return {yes}
            returned: 'yes'
    yes

### Programtically access responses:

    Vivado% puts "The user said: '${response}'"
    
    The user said: 'yes'

### Native Tk

Use the 'rexec' and 'rexec_wait' commands to send commands to the remote Tcl shell.  In the above case, the 'ask' command was used from the Tk Tunnel app, but the same behavior is observed using the native Tk commands:

    Vivado% set response [ ::tclapp::xilinx::tk_tunnel::rexec_wait {tk_messageBox -type "yesno" -message "Are you having fun?" -icon question -title "Custom Question"} ]

### Here are some more helper examples:

    Vivado% set response [ ::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::choose_color} ]
    
    #ff0000
    executed: puts stdout {#ff0000}
            returned: ''
    executed: set ::tclapp::xilinx::tk_tunnel::client_return {#ff0000}
            returned: '#ff0000'
    #ff0000


    Vivado% set response [ ::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::choose_dir} ]
    ...

    Vivado% set response [ ::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::open_file} ]
    ...
    

## Details

### Launching the Server

Run the following and see if a Tcl/Tk 8.5 shell is found using default settings:

    launch_server
    
The algorithm will check for a tclsh85 executable, and if not found then it will check tclsh. 

If this doesn't work, or you know where your Tcl/Tk 8.5 install lives, then you can use:

    # lin
    launch_server /usr/bin/tclsh85
    # win
    launch_server "C:/Program Files/tclsh85/bin/tclsh85.exe"

You can also add a path to the server launch script.  The default one is here: https://github.com/Xilinx/XilinxTclStore/blob/master/tclapp/xilinx/tk_tunnel/server/start.tcl

    launch_server "C:/Program Files/tclsh85/bin/tclsh85.exe" "C:/Users/admin/server.tcl"
    
### Starting the Client

Start the client with:

    start_client
    
### Sending commands

There are two main ways to send commands:

#### Blindly:
    
    rexec {puts "command for server"}
    
#### Waiting for response:
    
    # This will send the command return "value" to the server
    # The client will wait for the server to respond 
    # The server will respond with the return value, in this case "value"
    # Then response is set to the return value, in this case "value"
    set response [ rexec_wait {return "value"} ]

### All done!

That's pretty much all tk_tunnel was design to do.  

The power in this application is in the Tk commands that can be sent to the server.

There are several GUI/Tk helpers that will make creating GUIs easier, read on below.

## GUI Helpers

To make working with Tk a bit easier, several pre-configured GUI dialogs are provided:

    ok $msg
    ask $msg
    msg $msg
    failed $msg
    open_file 
    save_file 
    choose_dir
    choose_color
    ask_or_cancel $msg
    hide_server_start

All of these commands are available in the Tk shell that is launched when using the default server/start.tcl launch script.

These dialogs will return the button the user clicked on, or the object that was selected.

## Putting it all together

The above sections described how to pass commands to a Tk shell, and how to use GUI helpers.

Here is an example where we launch a GUI from with in Vivado:

    package require ::tclapp::xilinx::tk_tunnel
    namespace import ::tclapp::xilinx::tk_tunnel::*
    launch_server
    start_client
    set answer [ rexec_wait {ask "Are you having fun?"} ]
    puts $answer

This application is not limited to dialogs.  All Tk GUI commands are supported, take a look at: http://wiki.tcl.tk/14074

## Diving deeper

Here are the commands provided to enable pushing and pulling commands across the fence:

### Client

This proc will wait for a specified time (in ms)

    wait ?$time?

Executes a command on the Tk server (remote exec)

    rexec $cmd

Executes a command on the Tk server (remote exec), and waits for the response

    rexec_wait $cmd

Starts the client that will be sending the Tk commands

    start_client ?$host? ?$port?

Starts the server that the Tk commands will be sent to (launched from client). The user can bypass calling this proc and launch the server with a custom command, like: ```exec xterm -iconic -e /usr/local/tclsh ./custom_start_server.tcl &```

    launch_server ?$tclsh_path? ?$server_script?

Waits for client_return to be set (called by rexec_wait)

    wait_for_response 

This proc is called to connect a client to a server, it will wait until it is connected

    connect_to_server ?$host? ?$port?

### Server

This command broadcasts a command / response to all clients from the server, just type into stdin and press return

    broadcast $command

This proc is called when a stdin event occurs, this is because commands can actually be send from the server to the client as well, just type in the server

    stdin_event $socket

This proc is called when a socket event occurs

    socket_event $socket

This command launches the listening service on the server

    start_server ?$port?

Executes a command locally and broadcasts the return to the client (called by rexec_wait)

    exec_push_return $cmd

This proc is the callback function when the server receives a connection request

    accept_connection $socket $address $port

If that's not enough info, then jump into the code:
https://github.com/Xilinx/XilinxTclStore/blob/master/tclapp/xilinx/tk_tunnel/communication.tcl
