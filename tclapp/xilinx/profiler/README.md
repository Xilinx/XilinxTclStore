# Tcl Profiler App


## What is the Tcl Profiler?

The Tcl Profiler provides a way to profile Tcl apps (specified procs and commands) using
wall time, and generates a .out file that can be consumed by tools like kcachegrind.

## Getting started:

The Tcl Profiler app can be installed using the GUI (Tools > Xilinx Tcl Store...) or with:

    tclapp::install xilinx::profiler

After the app is installed it must be required once per Vivado invocation:

    # 1. Require the Tcl Profiler
    package require ::tclapp::xilinx::profiler

## Example program profile:

    # Example program to profile, this does not have to be in the same file
    namespace eval ::test {
      proc sleep {seconds} {
        set vwait 1
        after $seconds set vwait 0
        vwait vwait
      }
      proc first {} {
        sleep 1
        second
        sleep 1
      }
      proc second {} {
        sleep 3
      }
      proc main {} {
        sleep 1
        first
        second
        sleep 1
      }
    }
    
    # 2. Add the commands and procs you want to profile
    tclapp::xilinx::profiler::add_commands [ info procs ::test::first ]
    tclapp::xilinx::profiler::add_commands [ info procs ::test::second ]
    tclapp::xilinx::profiler::add_commands [ info procs ::test::main ]
    tclapp::xilinx::profiler::add_commands [ info procs ::test::sleep ]
    tclapp::xilinx::profiler::add_commands [ info commands after ]
    tclapp::xilinx::profiler::add_commands [ info commands vwait ]
    
    # 3. Start the profiler with start
    tclapp::xilinx::profiler::start
    test::main
    # 4. Stop the profiler with start
    tclapp::xilinx::profiler::stop
    
    # This will not be profiled even though it was added, i.e. the profiler is stopped
    test::main
    
    # The profiler can be restarted on demand
    tclapp::xilinx::profiler::start
    test::main
    tclapp::xilinx::profiler::stop
    
    # Once profiling is done the report can be generated, this may take some time
    tclapp::xilinx::profiler::write_report

