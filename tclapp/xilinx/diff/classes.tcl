####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   06/01/12
# Script name:    diff.tcl
# Classes:        html, report, design, diff
# Procedures:     new_report, new_diff, diff_lists, diff_reports, diff_props, diff_close_designs
# Tool Versions:  Vivado 2012.2
# Description:    This script is used to compare 2 designs that have been loaded into memory.
# Dependencies:   struct package
#                 stooop package
# Notes:          
#     For more information on STOOOP visit: http://wiki.tcl.tk/2165 
#     For more information on STRUCT visit: http://tcllib.sourceforge.net/doc/struct_set.html
# 
# Getting Started:
#     % source ./diff.tcl
#     % set report [new_report "diff.html" "Difference Report"]
#     % set of [new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} $report]
#     % diff_lists $of {get_cells -hierarchical} 
#     % diff_reports $of {report_timing -return_string}
#     % diff_props $of {get_timing_paths}
#     % diff_close_designs $of
#     % delete $of
#
####################################################################################################


# title: Vivado Design Differencing

namespace eval ::tclapp::xilinx::diff {
 # nothing is exported from this file
 # everything is for internal use by helpers.tcl
}


# section: Object Definitions

# class: report 
# This class is used to create a new report object. This class handles the general reporting mechanisms.
#

stooop::class ::tclapp::xilinx::diff::report {
    
    # proc: report 
    # Summary:
    # This is the contructor for this class.
    # 
    # Argument Usage: 
    #:     new report [channel]
    # 
    # parameters:
    #     channel        - This is the file handle or io channel that the report output will be 
    #                      printed to.
    # 
    # Return Value:
    #     report_object  - This object is used for writing to the report.
    # 
    # example:
    #     
    #:     # with a file
    #:     set object [new report [open "diff.log" w+]]
    #:     
    #:     # print to stdout
    #:     set object [new report]
    #
    
    proc report {this {channel {stdout}}} {
        set ($this,channel)        $channel
    }
    
    
    # proc: ~report 
    # Summary:
    # This is the destructor for this class.
    # 
    # Argument Usage: 
    #:     delete object
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    # 
    # example:
    #:     delete $object
    #
    
    proc ~report {this} {
        if { $($this,channel) != {stdout} } { close $($this,channel) }
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::write
    # Summary:
    # This takes a message and puts it directly to the channel property (an io channel object).
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::write object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg             - This is the message to be put to the io channel.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::write $object "My Message"
    #
    
    proc write {this msg} {
        puts $($this,channel) $msg
    }

    
    # proc: ::tclapp::xilinx::diff::report::stamp
    # Summary:
    # This method creates 2 info messages in the report with the current time and version info.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::stamp object 
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::stamp $object
    # 
    
    proc stamp {this} {
        catch { version } _version
        set _build     [lindex [lindex [split $_version \n] 0] 1]
        set _cl     [lindex [lindex [split $_version \n] 1] 1]
        ::tclapp::xilinx::diff::report::info $this "Created at [clock format [clock seconds]]"
        ::tclapp::xilinx::diff::report::info $this "Current Build: $_build\t\tChangelist: $_cl\t\tProcess ID: [pid]"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::start
    # Summary:
    # This method prints the title and stamps the report with time/date and version.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::start object [title]
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     title          - This is the title of the report.
    #                      Defaults to: "Difference Report"
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::start $object "My Title"
    # 
    
    stooop::virtual proc start {this {title "Difference Report"}} {
        ::tclapp::xilinx::diff::report::write $this "$title"
        ::tclapp::xilinx::diff::report::stamp $this
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::header
    # Summary:
    # This takes a message and formates it as a header in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::header object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::header $object "My Message"
    # 
    
    stooop::virtual proc header {this msg} {
        ::tclapp::xilinx::diff::report::write $this "\n\n@@ $msg"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::subheader
    # Summary:
    # This takes a message and formates it as a subheader in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::subheader object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::subheader $object "My Message"
    # 
    
    stooop::virtual proc subheader {this msg} {
        ::tclapp::xilinx::diff::report::write $this "$$ $msg"
        # set new_msg {}
        # foreach line [split $msg \n] { if { $line != {} } { lappend new_msg [string trim $line] } }
        # ::tclapp::xilinx::diff::report::write $this "$$ [join $new_msg \"\n\$\$ \"]"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::info
    # Summary:
    # This takes a message and formates it as a info in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::info object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::info $object "My Message"
    # 
    
    stooop::virtual proc info {this msg} {
        ::tclapp::xilinx::diff::report::write $this "** $msg"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::alert
    # Summary:
    # This takes a message and formates it as a alert in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::alert object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::alert $object "My Message"
    # 
    
    stooop::virtual proc alert {this msg} {
        ::tclapp::xilinx::diff::report::write $this "!! $msg"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::success
    # Summary:
    # This takes a message and formates it as a success in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::success object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::success $object "My Message"
    # 
    
    stooop::virtual proc success {this msg} {
        ::tclapp::xilinx::diff::report::write $this "== $msg"
    }
    
    
    # proc: ::tclapp::xilinx::diff::report::results
    # Summary:
    # This takes a message and formates it as a results in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::report::results object message
    # 
    # parameters:
    #     object         - This is the report object that was created with 'new report'.
    #     msg            - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::report::results $object "My Message"
    # 
    
    stooop::virtual proc results {this msg} {
        ::tclapp::xilinx::diff::report::write $this "$msg"
    }
    
}


# class: html 
# This class is used to create a new html report object. The html class should be considered as a
# child class that inherits from the report class.  This class overrides several of the reporting
# methods to generate HTML output, in place of the regular log commands.
#

stooop::class ::tclapp::xilinx::diff::html {

    # proc: html 
    # Summary:
    # This is the contructor for this class.
    # 
    # Argument Usage: 
    #:     new html [channel]
    # 
    # parameters:
    #     channel        - This is the file handle or io channel that the HTML output will be 
    #                      printed to.
    # 
    # Return Value:
    #     html_object    - This object is used for writing to the html report.
    # 
    # example:
    #:     set object [new html [open "diff.html" w+]]
    #
    
    proc html {this {channel {stdout}}} ::tclapp::xilinx::diff::report {
        $channel
    } {
        # constructor implementation
    }
    
    
    # proc: ~html 
    # Summary:
    # This is the destructor for this class.
    # 
    # Argument Usage: 
    #:     delete object
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    # 
    # example:
    #:     delete $object
    #
    
    proc ~html {this} {
        ::tclapp::xilinx::diff::report::write $this "</div></div></body></html>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::js 
    # Summary:
    # This is the static Java Script generator method.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::js
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::js
    #
    
    proc js {} {
        return {
        <script type='text/javascript' src='https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js'></script>
        <script type='text/javascript' src='https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.18/jquery-ui.min.js'></script>
        <script type='text/javascript'>
        $(document).ready(function(){
            $('h2').click(function() {
                $(this).next().next().toggle();
                return false;
            }).next().next().show();
            $('#toc').append('<p><b><i>Table of Contents:</i></b></p>')
            $('h3').each(function(i) {
                var current = $(this);
                current.attr('id', 'title' + i);
                $('#toc').append("<hr /><a id='link" + i + "' href='#title" +
                    i + "' title='" + current.text() + "'>" + 
                    current.html() + "</a>");
            });
        });
        </script>
        }
		# current.attr("tagName")
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::css
    # Summary:
    # This is the static Cascaded Stylesheets generator method.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::css
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::css
    #
    
    proc css {} {
        return {
        <style type='text/css'>
        p {margin: 0; margin-left: 20px; padding: 0;}
        pre {margin: 0; padding: 0;} 
        h2 {cursor: pointer;}
        #container { }
        #content { overflow: hidden; }
        #toc { width: 300px; border: 1px solid black; margin: 1em; padding: 1em; background: white; position: absolute; right: 0;}
        #toc a { display: block; color: #0094FF; overflow: hidden; text-decoration: none;}
        </style>
        }
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::start
    # Summary:
    # This is the start information for the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::start object [title]
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     title          - This is the title to be used for the report.
    #                      Defaults to "Difference Report"
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::start $object "My Difference Report"
    #:     ::tclapp::xilinx::diff::report::start $htmlobject "My Difference Report"
    #
    
    proc start {this {title "Difference Report"}} {
        ::tclapp::xilinx::diff::report::write $this "<html><head><title>$title</title><link rel='shortcut icon' href='http://www.xilinx.com/favicon.ico'>[::tclapp::xilinx::diff::html::css][::tclapp::xilinx::diff::html::js]</head><body><div id='container'><div id='toc'></div><div id='content'><h1>$title</h1><div>"
        ::tclapp::xilinx::diff::report::stamp $this
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::header
    # Summary:
    # This takes a message and formates it as a header in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::header object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::header $object "My Message"
    #:     ::tclapp::xilinx::diff::report::header $htmlobject "My Message"
    #
    
    proc header {this msg} {
        ::tclapp::xilinx::diff::report::write $this "</div><hr /><h2>&#x25BC;$msg</h2><div>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::subheader
    # Summary:
    # This takes a message and formates it as a subheader in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::subheader object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::subheader $object "My Message"
    #:     ::tclapp::xilinx::diff::report::results $htmlobject "My Message"
    #
    
    proc subheader {this msg} {
        set new_msg {}
        foreach line [split $msg \n] { if { $line != {} } { lappend new_msg [string trim $line] } }
        ::tclapp::xilinx::diff::report::write $this "<h3><pre>[join $new_msg \n]</pre></h3></div><div>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::info
    # Summary:
    # This takes a message and formates it as a info in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::info object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::info $object "My Message"
    #:     ::tclapp::xilinx::diff::report::info $htmlobject "My Message"
    #
    
    proc info {this msg} {
        ::tclapp::xilinx::diff::report::write $this "<pre style='color:gray;margin:0;padding:0' title='$msg'>$msg</pre>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::alert
    # Summary:
    # This takes a message and formates it as a alert in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::alert object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::alert $object "My Message"
    #:     ::tclapp::xilinx::diff::report::alert $htmlobject "My Message"
    #
    
    proc alert {this msg} {
        ::tclapp::xilinx::diff::report::write $this "<b><pre style='color:red'>$msg</pre></b>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::success
    # Summary:
    # This takes a message and formates it as a success in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::success object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::success $object "My Message"
    #:     ::tclapp::xilinx::diff::report::results $htmlobject "My Message"
    #
    
    proc success {this msg} {
        ::tclapp::xilinx::diff::report::write $this "<b><pre style='color:green'>$msg</pre></b>"
    }
    
    
    # proc: ::tclapp::xilinx::diff::html::results
    # Summary:
    # This takes a message and formates it as results in the report.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::html::results object message
    # 
    # parameters:
    #     object         - This is the html report object that was created with 'new html'.
    #     msg             - This is the message to be formatted.
    # 
    # example:
    #:     ::tclapp::xilinx::diff::html::results $object "My Message"
    #:     ::tclapp::xilinx::diff::report::results $htmlobject "My Message"
    #
    
    proc results {this msg} {
        ::tclapp::xilinx::diff::report::write $this "<pre style='color:red;margin:0;padding:0'>$msg</pre>"
    }
}


# class: design 
# This class is used to create a new design object. The design class is used to load
# designs into memory, force design to active, and to execute commands on a specific design.
#

stooop::class ::tclapp::xilinx::diff::design {
    
    # proc: design 
    # Summary:
    # This is the contructor for this class.
    # 
    # Argument Usage: 
    #:     new design design_command report_object
    # 
    # parameters:
    #     design_command - This is the command that will be executed and should result in 
    #                      the desired design being opened, and being the current_design.
    #     report_object  - This is the reporting object created with 'new report'
    # 
    # Return Value:
    #     design_object  - This object is used for referencing the design object.
    # 
    # example:
    #:     set object [new design {read_checkpoint design1.dcp} [new report]]
    #
    
    proc design {this cmd report} {
        set ($this,report)        $report
        set ($this,name)          {}
        set ($this,project)       {}
        set ($this,cmd)           $cmd
        load_cmd $this
    }
    
    
    # proc: ~design 
    # Summary:
    # This is the destructor for this class.
    # 
    # Argument Usage: 
    #:     delete object
    # 
    # parameters:
    #     object         - This is the design object that was created with 'new design design_command report_object'.
    # 
    # example:
    #:     delete $object
    #
    
    proc ~design {this} {}   
      
    
    # proc: ::tclapp::xilinx::diff::design::load_objs
    # Summary:
    # This method will force the design to be the current design, and then execute the command.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::design::load_objs object command [each_command]
    # 
    # parameters:
    #     object         - This is the design object that was created with 'new design'.
    #     command        - This is the command that should be executed once the design has been made
    #                      active.
    #     each_command   - This is the command that should be executed on each of resulting objects 
    #                      from executing 'cmd'. To reference each result you must use $obj in the 
    #                      command.  This is a fairly advanced ability and should only be used by
    #                      the most advanced users.
    # 
    # Return Value:
    #     objects        - The objects retrieved from executing the command parameter in this 
    #                      design, or if the each_command was specified, then a list of result
    #                      where each item in the list is itself a list with index 0 being the
    #                      the object and index 1 the result of each_command on $obj.
    #                      Example return with each command as 
    #:                      ::tclapp::xilinx::diff::design::load_objs $object {get_cells} {get_property IS_FIXED $obj}
    #:                          { 
    #:                              { {a} {1} }
    #:                              { {b} {0} }
    #:                              { {c} {0} }
    #:                          }
    # 
    # example:
    # 
    #:     # returns all of the cells for this design returned by get_cells
    #:     ::tclapp::xilinx::diff::design::load_objs $object {get_cells} 
    #:
    #:     # returns all of the cells for this design returned by get_cells -hierarchical
    #:     ::tclapp::xilinx::diff::design::load_objs $object {get_cells -hierarchical}
    #: 
    #:     # returns all of the cells for this design returned by get_cells -hierarchical
    #:     ::tclapp::xilinx::diff::design::load_objs $object {get_timing_paths} {report_property -all -return_string $obj}
    # 
    
    proc load_objs {this cmd {each_cmd {}}} {
        ::tclapp::xilinx::diff::report::info $($this,report) "Loading objects for design $($this,name)..."
        set results [lsort [execcmd $this $cmd]]
        ::tclapp::xilinx::diff::report::info $($this,report) "found: [llength $results]"
        if { $each_cmd != {} } {
            set result {}
            ::tclapp::xilinx::diff::report::info $($this,report) "Running on each: $each_cmd"
            foreach obj $results {
                lappend result [list "$obj" "[eval $each_cmd]"]
            }
        } else {
            set result $results
        }
        return $result
    }
    
    
    # proc: ::tclapp::xilinx::diff::design::load_cmd
    # Summary:
    # This executes the command to load the design, the 'cmd' property. 
    # 
    # notice:
    # Users should never need to use this command.
    # This method is called durring design object construction.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::design::load_cmd object
    # 
    # parameters:
    #     object         - This is the design object that was created with 'new design design_command report_object'.
    #                      The command that was set as the design_command parameter durring object creation will be
    #                      executed to open the design. This is stored using the object property 'cmd'.
    #
	# Return Value:
    #     1              - The design was opened and stored, or the design was already opened
    #     0              - The design failed to open
    # 
    
    proc load_cmd {this} {
        if { $($this,name) == {} } {
            ::tclapp::xilinx::diff::report::header $($this,report) "Loading design..."
            ::tclapp::xilinx::diff::report::subheader $($this,report) "$($this,cmd)"
            if { [eval $($this,cmd)] == [current_design] } {
                set ($this,project) [current_project]
                set ($this,name) [current_design]
                ::tclapp::xilinx::diff::report::success $($this,report) "Design open and stored"
                return 1
            } else {
                ::tclapp::xilinx::diff::report::alert $($this,report) "Design failed to open"
                return 0
            }
        } else {
            ::tclapp::xilinx::diff::report::success $($this,report) "Design is already open"
            return 1
        }
    }
    
    
    # proc: ::tclapp::xilinx::diff::design::execcmd
    # Summary:
    # This method will make a design the current design then execute a single command.
    # 
    # notice:
    # Users should never need to use this command.
    # This method is called durring ::tclapp::xilinx::diff::design::load_objs.
    #
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::design::execcmd object command
    # 
    # parameters:
    #     object         - This is the design object that was created with 'new design'.
    #     command        - This is the command that should be executed.
    # 
    # Return Value:
    #     objects        - The objects retrieved from executing the command.
    # 
    # example:
    # 
    #:     # returns all of the cells returned by get_cells
    #:     ::tclapp::xilinx::diff::design::execcmd $object {get_cells} 
    #:
    #:     # returns all of the cells returned by get_cells -hierarchical
    #:     ::tclapp::xilinx::diff::design::execcmd $object {get_cells -hierarchical}
    # 
    
    proc execcmd {this cmd} {
        activate $this
        return [eval $cmd]
    }
    
    
    # proc: ::tclapp::xilinx::diff::design::activate
    # Summary:
    # This method will make a design the current design (and project the current project).
    # 
    # notice:
    # Users should never need to use this command.
    # This method is called durring ::tclapp::xilinx::diff::design::execcmd.
    #
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::design::activate object
    # 
    # parameters:
    #     object         - This is the design object that was created with 'new design'.
    # 
    # Return Value:
    #     current_design - The current design is returned.
    # 
    # example:
    # 
    #:     # will make the design object the current design
    #:     ::tclapp::xilinx::diff::design::activate $object
    # 
    
    proc activate {this} {
        current_project $($this,project) 
        return [current_design $($this,name)]
    }
    
}


# class: diff 
# This class is used to create a new diff object. The diff class is used to couple a report object
# and two design objects to perform the differencing operations on.
#

stooop::class ::tclapp::xilinx::diff::diff {
    
    # proc: diff 
    # Summary:
    # This is the contructor for this class.
    # 
    # Argument Usage: 
    #:     new diff design_object_1 design_object_2 report_object
    # 
    # parameters:
    #     design_object_1 - This is the design object created with 'new design'
    #     design_object_2 - This is the design object created with 'new design'
    #     report_object  - This is the reporting object created with 'new report'
    # 
    # Return Value:
    #     diff_object    - This object is used for referencing the diff object.
    # 
    # example:
    #:     set object [new diff $design_object_1 $design_object_2 $report_object]
    #    
    
    proc diff {this d1 d2 report} {
        set ($this,report)        $report
        set ($this,d1)            $d1
        set ($this,d2)            $d2
    }
    
    
    # proc: ~diff 
    # Summary:
    # This is the destructor for this class.
    # 
    # Argument Usage: 
    #:     delete object
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    # 
    # example:
    #:     delete $object
    #
    
    proc ~diff {this} {
        if { [info exists ($this,report)] } { stooop::delete $($this,report) }
        if { [info exists ($this,d1)] } { stooop::delete $($this,d1) }
        if { [info exists ($this,d2)] } { stooop::delete $($this,d2) }
    }
    
    
    # proc: ::tclapp::xilinx::diff::diff::compare_lists
    # Summary:
    # This method will execute a command on each design and compare the results in a nonsequential 
    # way. This method expects the commands to return a list for both designs.
    # 
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::compare_lists object command
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     command        - This is the command to be executed and of which the results will be 
    #                       compared.
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    # example:
    # 
    #:     # compares all of the cells for these designs returned by get_cells
    #:     ::tclapp::xilinx::diff::diff::compare_lists $object {get_cells} 
    #:
    #:     # compares all of the cells for these designs returned by get_cells -hierarchical
    #:     ::tclapp::xilinx::diff::diff::compare_lists $object {get_cells -hierarchical}
    #:
    #:     # compares all of the nets for these designs returned by get_nets -hierarchical
    #:     ::tclapp::xilinx::diff::diff::compare_lists $object {get_nets -hierarchical}
    #: 
    #:     # compares all of the timing paths for these designs returned by get_timing_paths
    #:     ::tclapp::xilinx::diff::diff::compare_lists $object {get_timing_paths}
    #:
    #:     # multi-line commands are accepted
    #:      ::tclapp::xilinx::diff::diff::compare_lists $object {
    #:         set paths [get_timing_paths -max_paths 1000]
    #:         return [get_property SLACK [lsort $paths]]
    #:      }
    # 
    
    proc compare_lists {this cmd} {
        ::tclapp::xilinx::diff::report::header $($this,report) "Comparing lists..."
        ::tclapp::xilinx::diff::report::subheader $($this,report) "$cmd"
        set d1_results [join [::tclapp::xilinx::diff::design::load_objs $($this,d1) $cmd] \n]
        set d2_results [join [::tclapp::xilinx::diff::design::load_objs $($this,d2) $cmd] \n]
        set d1_only [::struct::set difference $d1_results $d2_results]
        set d2_only [::struct::set difference $d2_results $d1_results]
        if { [llength $d1_only] == 0 && [llength $d2_only] == 0 } {
            ::tclapp::xilinx::diff::report::success $($this,report) "The lists are equivalent"
        } else {
            ::tclapp::xilinx::diff::report::alert $($this,report) "Differences found:\nDesigns $::tclapp::xilinx::diff::design::($($this,d1),name) has [llength $d1_only] unique:\n\t[join $d1_only \n\t]\nDesigns $::tclapp::xilinx::diff::design::($($this,d2),name) has [llength $d2_only] unique:\n\t[join $d2_only \n\t]"
        }
        return [expr [llength $d1_only] + [llength $d2_only]]
    }
    
    
    # proc: ::tclapp::xilinx::diff::diff::compare_props
    # Summary:
    # This method will execute a command on each design and compare the properties of the results.
    # This method expects the commands to return a list of objects for both designs. Those object's
    # properties will be compared.
    #
    # notice:
# When comparing large numbers of objects the lists to compare properties grow at a 
    # a multiple of the number of properties for each object. This can consume large amounts of
    # memory, and it is stongly recommended that the objects be limited to 10,000 per invocation.
    #  
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::compare_props object command
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     command        - This is the command to be executed and of which the properties of the 
    #                       results will be compared.
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    # example:
    # 
    #:     # compares all properties of the cells for these designs returned by get_cells
    #:     ::tclapp::xilinx::diff::diff::compare_props $object {get_cells} 
    #:
    #:     # compares all properties of the cells for these designs returned by get_cells -hierarchical
    #:     ::tclapp::xilinx::diff::diff::compare_props $object {get_cells -hierarchical}
    #:
    #:     # compares all properties of the nets for these designs returned by get_nets -hierarchical
    #:     ::tclapp::xilinx::diff::diff::compare_props $object {get_nets -hierarchical}
    #: 
    #:     # compares all properties of the timing paths for these designs returned by get_timing_paths
    #:     ::tclapp::xilinx::diff::diff::compare_props $object {get_timing_paths}
    #:
    #:     # multi-line commands are accepted
    #:      ::tclapp::xilinx::diff::diff::compare_props $object {
    #:         set paths [get_timing_paths -max_paths 1000]
    #:         return $paths
    #:      }
    # 
    
    proc compare_props {this cmd} {
        ::tclapp::xilinx::diff::report::header $($this,report) "Comparing properties..."
        ::tclapp::xilinx::diff::report::subheader $($this,report) "$cmd"
        set d1_props [::tclapp::xilinx::diff::design::load_objs $($this,d1) $cmd {report_property -all -return_string $obj}]
        set d2_props [::tclapp::xilinx::diff::design::load_objs $($this,d2) $cmd {report_property -all -return_string $obj}]
        ::tclapp::xilinx::diff::report::info $($this,report) "Comparing [llength $d1_props] (with [llength $d2_props]) objects..."
        set diffs [lsort [::struct::set symdiff $d1_props $d2_props]]
        if { [llength $diffs] } {
            ::tclapp::xilinx::diff::report::info $($this,report) "Found [expr [llength $diffs] / 2] difference(s):"
            foreach {d1_diff d2_diff} $diffs {
                ::tclapp::xilinx::diff::report::info $($this,report) "Property differences exist for: [lindex $d1_diff 0] (and [lindex $d2_diff 0]):"
                set d1_split [split [lindex $d1_diff 1] \n]
                set d2_split [split [lindex $d2_diff 1] \n]
                fcs_diff $this $d1_split $d2_split
            }
        } else {
            ::tclapp::xilinx::diff::report::success $($this,report) "All properties are equivalent"
        }
        return [llength $diffs]
    }
    
    
    # proc: ::tclapp::xilinx::diff::diff::compare_reports
    # Summary:
    # This method will execute a command on each design and compare resulting reports in a 
    # sequential way. This method expects the commands to return a string.
    #
    # notice:
    # Sometimes reports will have a datestamp, and thus show differences even when
    # the contents of the reports are the same.  It is up to the user to differentiate this filter
    # or correctly remove the acceptable differences from the reports.
    #  
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::compare_reports object command
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     command        - This is the command to be executed and of which the resulting reports 
    #                       will be compared.
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    # example:
    # 
    #:     # compares reports of timing for the first 1000 paths
    #:     ::tclapp::xilinx::diff::diff::compare_reports $object {report_timing -return_string -max_paths 1000}
    #:
    #:     # compares reports of drc
    #:     ::tclapp::xilinx::diff::diff::compare_reports $object {report_drc -return_string}
    #:
    #:     # compares reports of the routes for all nets
    #:     ::tclapp::xilinx::diff::diff::compare_reports $object {report_route_status -return_string -of_objects [get_nets]}
    #: 
    #:     # multi-line commands are accepted
    #:      ::tclapp::xilinx::diff::diff::compare_reports $object {
    #:         set nets [get_nets]
    #:         set subset_nets [lrange $nets 0 10]
    #:         return [list [report_route_status -return_string -of_objects [get_nets $subset_nets]]]
    #:      }
    # 
    
    proc compare_reports {this cmd {unique_name {temp}}} {
        upvar #0 tcl_platform(platform) tcl_platform
        set nt_threshold 2000
        ::tclapp::xilinx::diff::report::header $($this,report) "Comparing reports..."
        ::tclapp::xilinx::diff::report::subheader $($this,report) "$cmd"
        if { [lsearch $cmd "-return_string"] == -1 } { ::tclapp::xilinx::diff::report::alert $($this,report) "Comparing reports without '-return_string' switch may not work as expected." }
        set d1_results [::tclapp::xilinx::diff::design::load_objs $($this,d1) "list \[$cmd\]"]
        set d2_results [::tclapp::xilinx::diff::design::load_objs $($this,d2) "list \[$cmd\]"]
        set d1_split [split $d1_results \n]
        set d2_split [split $d2_results \n]
        ::tclapp::xilinx::diff::report::info $($this,report) "Comparing [llength $d1_split] (with [llength $d2_split]) lines..."
        if { $tcl_platform == "unix" } {
            set return [lin_diff $this $d1_split $d2_split $unique_name]
        } else {
            if { [expr [llength $d1_split] + [llength $d2_split]] > $nt_threshold } {
                ::tclapp::xilinx::diff::report::info $($this,report) "Comparing large reports, switching to a faster compare algorithm\n\t(limit is total compare lines $nt_threshold)"
                set return [fcs_diff $this $d1_split $d2_split]
            } else {
                set return [lcs_diff $this $d1_split $d2_split]
            }
        }
        if { $return == 0 } { ::tclapp::xilinx::diff::report::success $($this,report) "The reports are equivalent" }
        return $return
    }
    

    # proc: ::tclapp::xilinx::diff::diff::lin_diff
    # Summary:
    # This method will execute the linux diff command to perform a sequential difference.
    #
    # notice:
    # Users should never need to use this method.
    # This method is called durring ::tclapp::xilinx::diff::diff::compare_reports on unix machines.
    #  
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::lin_diff object results1 results2 [unique_name]
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     results1       - This is the first string to be compared. 
    #     results2       - This is the second string to be compared. 
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    
    proc lin_diff {this d1_results d2_results {unique_name {temp}}} {
        set d1_file        d1_${unique_name}.log        
        set d2_file        d2_${unique_name}.log        
        set diff_file      diff_${unique_name}.log        
        
        ::tclapp::xilinx::diff::report::info $($this,report) "Writing Temp Files for Report Diffing..."
        set d1_temp [open $d1_file "w"]
        puts $d1_temp [join $d1_results \n]
        close $d1_temp
        set d2_temp [open $d2_file "w"]
        puts $d2_temp [join $d2_results \n]
        close $d2_temp
        
        ::tclapp::xilinx::diff::report::info $($this,report) "Running Temp File Diff..."
        catch {exec diff $d1_file $d2_file > $diff_file}
        set diff_temp [open $diff_file "r"]
        set diff [split [read $diff_temp] \n]
        close $diff_temp
        
		if { ${unique_name} == {temp} } {
			::tclapp::xilinx::diff::report::info $($this,report) "Deleting Temp Files..."
			file delete $d1_file
			file delete $d2_file
			file delete $diff_file
		}
        
        set diff_length [llength $diff]
        if { $diff_length != 0 } { 
            ::tclapp::xilinx::diff::report::alert $($this,report) "Differenes found:\n<\t$::tclapp::xilinx::diff::design::($($this,d1),name)\n>\t$::tclapp::xilinx::diff::design::($($this,d2),name)\n---"
            ::tclapp::xilinx::diff::report::results $($this,report) [join $diff \n]    
        }
        
        return $diff_length
    }
    
    
    # proc: ::tclapp::xilinx::diff::diff::fcs_diff
    # Summary:
    # This method will execute a custom difference algorithm, which is design to be fast, but not as
    # clean to read because it is a line based difference.
    #
    # notice:
    # Users should never need to use this method.
    # This method is called durring ::tclapp::xilinx::diff::diff::compare_reports on windows machines with large reports and 
    # always for ::tclapp::xilinx::diff::diff::compare_props - where a line comparison is actually preferred.
    #  
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::fcs_diff object results1 results2
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     results1       - This is the first string to be compared. 
    #     results2       - This is the second string to be compared. 
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    
    proc fcs_diff {this d1_results d2_results} {
        set d1_length  [llength $d1_results]
        set d2_length  [llength $d2_results]
        set d1_pointer 0
        set d2_pointer 0
        set diffs 0
        ::tclapp::xilinx::diff::report::info $($this,report) "Comparing Lines..."
        while {$d1_pointer < $d1_length && $d2_pointer < $d2_length} {
            set d1_string [lindex $d1_results $d1_pointer]
            set d2_string [lindex $d2_results $d2_pointer]
            if { $d1_string == $d2_string } {
                incr d1_pointer
                incr d2_pointer
            } else {
                if { $diffs == 0 } { ::tclapp::xilinx::diff::report::alert $($this,report) "Differenes found:\n<\t$::tclapp::xilinx::diff::design::($($this,d1),name)\n>\t$::tclapp::xilinx::diff::design::($($this,d2),name)\n---" }
                incr diffs
                set d1_hit_in_d2 [lsearch -start $d2_pointer $d2_results $d1_string]
                set d2_hit_in_d1 [lsearch -start $d1_pointer $d1_results $d2_string]                
                if { $d1_hit_in_d2 == -1 } { set d1_hit_in_d2 $d2_pointer }
                if { $d2_hit_in_d1 == -1 } { set d2_hit_in_d1 $d1_pointer }
                if { $d1_hit_in_d2 != $d2_pointer && $d2_hit_in_d1 != $d1_pointer } {
                    if { [expr ($d1_hit_in_d2 - $d2_pointer) > ($d2_hit_in_d1 - $d1_pointer)] } {
                        set d1_pointer $d2_hit_in_d1
                        set d1_hit_in_d2 $d2_pointer
                    } else {
                        set d2_hit_in_d1 $d1_pointer
                        set d2_pointer $d1_hit_in_d2
                    }
                }            
                set d1_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [list ${d1_pointer} ${d2_hit_in_d1}]] { + 1],[expr }] + 1\]"] {}]
                set d2_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [list ${d2_pointer} ${d1_hit_in_d2}]] { + 1],[expr }] + 1\]"] {}]
                ::tclapp::xilinx::diff::report::results $($this,report) "${d1_lines}c${d2_lines}\n< "
                ::tclapp::xilinx::diff::report::results $($this,report) [join [lrange $d1_results $d1_pointer $d2_hit_in_d1] "\n< "]
                ::tclapp::xilinx::diff::report::results $($this,report) "---\n> "
                ::tclapp::xilinx::diff::report::results $($this,report) [join [lrange $d2_results $d2_pointer $d1_hit_in_d2] "\n> "]
                incr d1_pointer
                incr d2_pointer
            }
        }
        return $diffs
    }
    
    
    # proc: ::tclapp::xilinx::diff::diff::lcs_diff
    # Summary:
    # This method will execute a longest common subsequence difference algorithm (from the struct 
    # library), which is designed to be very easy to read, but has known limitations on speed when
    # comparing large files. 
    #
    # notice:
    # Users should never need to use this method.
    # This method is called durring ::tclapp::xilinx::diff::diff::compare_reports on windows machines with small reports.
    #  
    # Argument Usage: 
    #:     ::tclapp::xilinx::diff::diff::lcs_diff object results1 results2
    # 
    # parameters:
    #     object         - This is the diff object that was created with 'new diff'.
    #     results1       - This is the first string to be compared. 
    #     results2       - This is the second string to be compared. 
    # 
    # Return Value:
    #     diff_count     - The number of differences identified
    # 
    
    proc lcs_diff {this d1_results d2_results} {
        ::tclapp::xilinx::diff::report::info $($this,report) "Analyzing Longest Common Subsequence..."
        set lcs [::struct::list longestCommonSubsequence $d1_results $d2_results]
        ::tclapp::xilinx::diff::report::info $($this,report) "Inverting Longest Common Subsequence..."
        set ilcs [::struct::list lcsInvert $lcs [llength $d1_results] [llength $d2_results]]
        if { [llength $ilcs] != 0 } { 
            ::tclapp::xilinx::diff::report::alert $($this,report) "Differenes were found in the reports:\n<\t$::tclapp::xilinx::diff::design::($($this,d1),name)\n>\t$::tclapp::xilinx::diff::design::($($this,d2),name)\n---"
        }
        foreach sequence $ilcs {
            set d1_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 1]] { + 1],[expr }] + 1\]"] {}]
            set d2_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 2]] { + 1],[expr }] + 1\]"] {}]
            ::tclapp::xilinx::diff::report::results $($this,report) "${d1_lines}[string index [lindex $sequence 0] 0]${d2_lines}\n> "
            ::tclapp::xilinx::diff::report::results $($this,report) [join [eval "lrange \$d1_results [join [lindex $sequence 1] { }]"] "\n> "]
            ::tclapp::xilinx::diff::report::results $($this,report) "---\n< "
            ::tclapp::xilinx::diff::report::results $($this,report) [join [eval "lrange \$d2_results [join [lindex $sequence 2] { }]"] "\n< "]
        }
        return [llength $ilcs]
    }
    
}

# Provide everything in this file as a package for use by helpers.tcl
package provide ::tclapp::xilinx::diff::classes 1.2
#######################
