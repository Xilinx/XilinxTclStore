# args.tcl --
#
# Vivado Tcl argument parser
# Tightly integrated with Vivado Tcl.

package require Tcl 8.5
package require rdi::commontasks 1.2014.4

namespace eval ::tclapp::support::args {}

namespace eval ::tclapp::support::args {

    # initialization ----------------------------------------------------------
    variable systemCategories [dict create]
    
    proc cacheSystemCategories {} {
	# Summary : set up the canonical dictionary of system categories. 
	#  We may not add user commands to any of these pre-existing categories
	
	# Argument Usage:
	
	# Return Value:
	# none.  However, the namespace variable "systemCategories" is
	# populated with a dictionary whose keys are the verboten
	# categories
	
	# Category:  documnetation
	
	variable systemCategories
	
	# grab the list of pre-existing categories
	set preExistingCategories [help -list]
	foreach preExistingCategory $preExistingCategories {
	    dict set systemCategories $preExistingCategory 1
	}
    }
    
    # execute the caching mechanism
    cacheSystemCategories

    proc userProcs {} {
        # Summary: Return a list of currently registered Tcl apps

        # Argument Usage:

        # Return Value:
        # List of apps registered with Vivado Tcl
        return [list_apps -installed]
    }

    # --------------------------------------------------------------
}
    
    
proc ::tclapp::support::args::get_arg { argName } {
    # Summary: returns the value of the argument named "argName" in the calling procedure
    
    # Argument Usage:
    # argName : name of the argument in the calling procedure for which to fetch the value
    
    # Return Value: 
    #  returns the value for the argument specified on the command line
    #  of the calling function
    
    # Examples:
    #
    # proc multiply args {
    #      # Argument Usage:
    #      # x : a number
    #      # y : another number
    #
    #      return [expr [::tclapp::support::args::get_arg x] * [::tclapp::support::args::get_arg y]]
    # }
    
    # Categories:
    # system
    # documentation
    # argument parsing
    
    # build the command to execute in my parent's stack frame:
    append queryCmd {::tclapp::support::args::fetch $__argVals__(} $argName {)}
    
    # first see if we've built the cache already
    if { [uplevel 1 {info exists __argVals__ }] } {
        return [uplevel 1 $queryCmd]
    }
    
    # couldn't find it, so build the cache
    build_get_arg_cache
    
    # return the requested argument's value
    return [uplevel 1 $queryCmd]
}

proc ::tclapp::support::args::arg_exists { argName } {
    # Summary: returns 1 if ::tclapp::support::args::get_arg will find a value for the argument $argname
    
    # Argument Usage:
    # argName : the name for an argument in the calling procedure
    
    # Return Value:
    # returns 1 if the calling procedure has been invoked with an argument whose
    # name is $argName, or if an argument whose name is $argName
    # has been declared in the Argument Usage section as being either (1) optional
    # with an explicit default value specified, or (2) a switch.   returns 0 otherwise.
    
    # Examples:
    #
    # proc safe_multiply args {
    #      # Argument Usage:
    #      # x : a number
    #      # y : another number
    #      
    #      if { [::tclapp::support::args::arg_exists x] || [::tclapp::support::args::arg_exists y]} {
    #           puts "one or both arguments unspecified"
    #           return 0
    #      }
    #      return [expr [::tclapp::support::args::get_arg x] * [::tclapp::support::args::get_arg y]]
    # }
    
    # Categories: documentation, system, argument processing
    
    
    # first see if we've built the cache already
    if { [uplevel 1 {info exists __argVals__ }] } {
        return [uplevel 1 [append dummy {info exists __argVals__(} $argName {)} ]]
    }
    
    # couldn't find it, so build the cache
    build_get_arg_cache
    
    # return the requested argument's value
    return [uplevel 1 [append dummy {info exists __argVals__(} $argName {)} ]]
}



proc ::tclapp::support::args::fetch { argName } {
    # Summary: only used as a utility function for proc get_arg.
    
    # Argument Usage:
    # argName : the value to be returned
    
    # Return Value:
    # exactly what was passed in :-)

    # Categories:
    # utility
    
    return $argName
}

proc ::tclapp::support::args::build_get_arg_cache {} {
    # Summary: utility for procGet arg, builds the argument cache
    
    # Argument Usage:
    
    # Return Value:
    # none

    # Categories: system, non-user visible
    
    # here is where the magic happens: 
    
    # get the information about the calling frame
    set procInfo [info level -2]
    
    # get the name of the calling proceedure
    set procName [lindex  $procInfo 0]
    set procName [uplevel 2 namespace which $procName]
    
    # now calculate the arguments of the calling proceedure
    set procArgs [lreplace $procInfo 0 0]
    
    # now get the body of the calling proceedure
    set procBody [info body $procName]
    
    # see if t has been specified:
    if { ! [get_documentation_section $procBody {Argument Usage} argUsageSpecs] } {
        puts "Error : could not find argument documentation in procedure $procName"
        return;
    }
    
    # build the arg cache in the caller's stack frame
    set cmd [list {::tclapp::support::args::get_args} $procName $argUsageSpecs $procArgs {__argVals__}]
    uplevel 2 $cmd
}

################################################################################
# NOTE: I have discovered that this proc is defined twice in this file. The
# second definition is about 400 lines down, and is the one acutally executed
# by tcl. So this is really dead code (I think). Since I don't have much
# tcl knowledge, I'm reluctant to remove it, but be warned!. dm.
################################################################################

proc ::tclapp::support::args::parse_arg_usage_spec { argUsageSpec results } {
    # Summary: Returns 1 if the argument spec parsed out ok, 0 otherwise.
    
    # Argument Usage:
    # spec : a string which purports to hold an argument spec.
    # results : an array containing the results of parsing the argument spec
    
    # Return Value:
    # 1 is returned if we can recognize this as a well-formed argument spec
    # 0 is returned if we cannot recognize it as such.
    # 
    # If the function returns 1, then the following data are
    # communicated back to the caller via the "results" argument.
    # The following keys will have values set:
    # results(isOptional)    : 1 implies this is a spec for an optional argument
    # results(isPositional)  : 1 implies this is a spec for a positional argument,
    # results(isSwitch)      : 1 implies this is a boolean switch
    # results(defaultValue)  : if the spec indicates a default value for this
    #                        : argument, it is set to the indicated value.
    #                        : if there is no default, the value is <UNSET>
    # results(argName)       : a string which is the name of the argument
    # results(description)   : a string briefly describing the argument
    #
    # if the function returns 0, then the value of "results"
    # is undefined.
    
    # Categories:
    # system
    # non-user visible
    
    # enble pass-by-reference for the output arg
    upvar $results iResults
    # clear it out
    if { [array exists iResults] } {
        array unset iResults
    }
    
    if { [info exists iResults] } {
        unset iResults
    }
    
    # initialize to uninitialized :-)
    set iResults(isOptional)    {<UNSET>}
    set iResults(isPositional)  {<UNSET>}
    set iResults(isSwitch)      {<UNSET>}
    set iResults(defaultValue)  {<UNSET>}
    set iResults(argName)       {<UNSET>}
    set iResults(description)   {<UNSET>}
    
    # e.g. # [-report_name <arg> = report.txt] : when specified write a report to the specified name
    if { [regexp {[\s]*\[[\s]*-([^<]*)[\s]*\<arg\>[\s]*=[\s]*([^\]]*)\][\s]*:([^\n]*)} $argUsageSpec -> name def desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(defaultValue)  [string trim $def]
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-report_name <arg>] : when specified write a report to the specified name
    if { [regexp {[\s]*\[[\s]*-([^<]*)[\s]*\<arg\>[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-no_whammies] : when specified, don't allow whamies
    if { [regexp {[\s]*\[[\s]*-(no_[^:]*)[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      1
        set iResults(defaultValue)  1
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-use_smart_algorithm] : do it the good way, not the bad way
    if { [regexp {[\s]*\[[\s]*-([^:]*)[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      1
        set iResults(defaultValue)  0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g. # [pattern=*]     : Match cell names against patterns
    if { [regexp {[\s]*\[[\s]*([^=]*)=[\s]*([^\]]*)\][\s]*:([^\n]*)} $argUsageSpec -> name def desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  1
        set iResults(isSwitch)      0
        set iResults(defaultValue)  [string trim $def]
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # -report_name <arg> : write a report to the specified name
    if { [regexp {[\s]*[\s]*-([^<]*)[\s]*\<arg\>[\s]*[\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    0
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g. # name : just a simple positional argument
    if { [regexp {[\s]*([^:]*):([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    0
        set iResults(isPositional)  1
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    return 0
}

############################################################################
# NOTE: This proc also appears in tcl_lint.tcl (and so probably do a lot
# of other procs in this file - argh! So if you change this proc, consider
# updating the version in tcl_lint.tcl to match.
############################################################################

proc ::tclapp::support::args::get_documentation_section { procBody sectionName section } {
    # Summary : extracts the documentation section named $section from $body
    
    # Argument Usage :
    # procBody     : a string which is the body of a procedure
    # sectionName  : a string which names the section to be extracted
    # section      : if the section is found, $section contains the extracted text
    
    # Return Value:
    # returns 1 of the section was successfully found and extracts.
    #
    # If the function returns 1, then $section is populated with the extracted
    # section, stripped of the leading # on each line
    #
    # If the function returns 0, then $section is undefined.
    
    # Categories:
    # documentation
    # help system
    
    
    # pass the section by value
    upvar $section iSection
    
    if { [array exists iSections] } {
        array unset iSection
    }
    
    if { [info exists iSection] } {
        unset iSection
    }
    
    # initialize it to {}
    set iSection {}
    
    # prepair the search string
    set regExpString "\#\[ \\t\]*$sectionName\[ \\t\]*:\[ \\t\]*(\[^\\n\]*)\n"
    
    # find where the section starts
    if { ![regexp -indices $regExpString $procBody nspec pos] } {
        return 0
    }
    
    # Handle the stuff on the same line as the section tag:
    set firstLine [string range $procBody [lindex $pos 0] [lindex $pos 1]]
    if { "" != $firstLine } {
        append iSection "$firstLine\n"
    }
    
    set startSpecPos [expr [lindex $pos 1] + 2]
    
    # find where the section ends -- must end with two consecutive newlines
    if { ![regexp -start [lindex $nspec 0] -indices {\n[\s]*\n} $procBody pos] } {
        return 0
    }
    set endSpecPos [expr [lindex $pos 0] -1 ]
    
    # extract the text
    set buffer [string trim [string range $procBody $startSpecPos $endSpecPos]]
    
    # now see that each line is a comment line
    set lines [split $buffer "\n"]
    
    foreach line $lines {
        # just to make it easier to process
        set line [string trim $line]
        
        # all other lines but the first one must be 
        if { 0 != [string first "\#" $line ] } {
            return 0
        }
        
        # remove the space trailing the pound sign--if indeed it is a space
        if { 0==[string first "# " $line] } {
            set line [string range $line 2 end]
        } elseif { 0==[string first "#" $line] } {
            set line [string range $line 1 end]
        }
        
        # now append it to the output
        append iSection "$line\n"
    }
    
    # success!!
    return 1
}

proc ::tclapp::support::args::get_apps_for_category { categoryName results } {
    # Summary: query which user-written apps which belong to a category.
    
    # Argument Usage:
    # categoryName : a string which is the category we are querying for
    # results : array whose keys are app names and values are descriptions of the apps
    
    # Return Value:
    # the procedure returns no value.  Instead, it populates an array
    # supplied by the user (the "results" argument) such that:
    # the keys of the array are the names user supplied apps-fully qualified
    # as to their namespaces 
    # and the values are the summary description for the function
    # For example:
    # key   {::util::find_unsyncronized_paths}
    # value {Return a list of clock-domain crossing paths which lack a synchronizer}
    
    # Categories:
    # documenation
    # help system
    
    # set up the return-by ref array
    upvar $results iResults

    if { [array exists iResults] } {
        array unset iResults
    }
    
    if { [info exists iResults] } {
        unset iResults
    }

    
    # blow away any pre-existing stuffs
    array unset iResults
    
    # run through each proc, see if it has a "Categories" section
    foreach searchProc [userProcs] {

        set searchBody [info body $searchProc]
        if { ! [get_documentation_section $searchBody {Categories} sectionText] } {
            # has no category associated with it; just bail
            continue
        }
        
        # see if we match the category information
        if { ! [regexp $categoryName $sectionText] } {
            # don't match, just bail
            continue
        }
        
        # since we match, see if we've got a summry section
        # (should have, but just for robustness sake...)
        if { ! [get_documentation_section $searchBody {Summary} summaryText] } {
            continue
        }
        
        set iResults($searchProc) [string trim $summaryText]
    }
}


proc ::tclapp::support::args::get_args { procName argUsageSpecs procArgs argVals_ext } {
    # Summary: populates an array which can be used to access the value of arguments of the calling procedure.
    
    # Argument Usage:
    # procName : name of the proc being called
    # argUsage : a valid argument usage spec block extracted from the body of a proc
    # procArgs : a list of arguments passed into a proc
    # argVals : an array passed by value which is populated with values derived from matching argUsageSpecs to procArgs
    
    # Return Value: 
    # If we can sucessfully parse $argUsageSpecs and match it up against $procArgs
    # this returns 1.  Otherwise it returns 0.
    # 
    # If this procedure returns 1, then the argument "argVals" will be populated with
    # an array whose keys are the names of the arguments as specified 
    # in $argUsageSpecs, and whose values are the matched values derived from $procArgs
    
    # Categories:
    # system
    # non-user visible
    
    # set up the call-by ref returner array
    upvar $argVals_ext argVals
    
    if { [array exists argVals] } {
        array unset argVals
    }
    
    if { [info exists argVals] } {
        unset argVals
    }
    
    # sanitize, and split for ease of processing
    set argUsageSpecs [string trim $argUsageSpecs]
    set argUsageSpecs [split $argUsageSpecs "\n"]
    
    # this array maps each argument specified on the command line to
    # its value, as specified on the command line.  If any of the
    # values are "<UNSET>" then there is an error in the command line
    # parsing.
    array unset argVals {}
    foreach argUsageSpec $argUsageSpecs {
        # parse the arg spec and extract the relevant info
        ::tclapp::support::args::parse_arg_usage_spec $argUsageSpec results
        
        # accumulate results over all of the parsed specs
        set isOptional($results(argName))    $results(isOptional)
        set isPositional($results(argName))  $results(isPositional)
        set isSwitch($results(argName))      $results(isSwitch)
        set defaultValue($results(argName))  $results(defaultValue)
        set description($results(argName))   $results(description)
        
        # accumulate the positional arguments in order
        if { $results(isPositional) } {
            lappend positionalArgs $results(argName)
        }
        
        # initialize the argVals array
        if { $results(isOptional) } {
            # if this is an optional argument see if it has
            # a default value.  Fill it it; it might be overwritten later
            if { "<UNSET>" != $results(defaultValue) } {
                set argVals($results(argName)) $results(defaultValue)
            }
        } else {
            # this is a mandatory argument, indicate that it must
            # eventualy be set
            set argVals($results(argName)) "<UNSET>"
        }
    }
    
    # run through the command-line arguments and match them
    # up against the specs to find the values specified
    
    while { {} != $procArgs } {
        # see if this is an argument which consumes an argument
        if { [regexp {^-([^\s]+)[ \t]+([^\s]+)} $procArgs -> procArg foundArgVal] } {
            # test for valid name
            if { ! [info exists isPositional($procArg) ] } {
                puts "Error : $procArg is in proc $procName is not a valid argument"
                return 0;
            }
            
            # test to see if its really a positional argument or not
            if { $isPositional($procArg) } {
                puts "Error : not expecting \"-\" in front of $procArg in proc $procName"
                return 0;
            }
            
            # does $procArg consume an argument?
            if { ! $isSwitch($procArg) } {
                # consume the argument and move on
                set argVals($procArg) $foundArgVal
                set procArgs [lreplace $procArgs 0 1]
                continue;
            }
            # if not fall through to next test--this migh be a switch
        }
        
        # see if this is a switch
        if { [regexp {^-([^\s]*)} $procArgs -> procArg] } {
            if { ! [info exists isSwitch($procArg) ] } {
                puts "Error : $procArg in proc $procName is not a valid argument"
            }
            
            if { $isSwitch($procArg) } {
                # paste in the **opposite** of the default value
                set argVals($procArg) [expr ! $defaultValue($procArg)]
                # consume the argument and move on
                set procArgs [lreplace $procArgs 0 0]
                continue;
            } else {
                # error out, this hasn't been speced right
                puts "Error : $procArg in proc $procName is not a valid argument"
                return 0;
            }
        }
        
        # if we get here, its a positional argument, so try to match it up
        # with positional arguments we've got
        if { 0 == [llength $positionalArgs] } {
            puts "Error: too many positional arguments specified for proc $procName"
            return 0;
        }
        
        # consume a positional argument
        set positionalArg [lindex $positionalArgs 0]
        set positionalArgs [lreplace $positionalArgs 0 0]
        set settingArgVal [lindex $procArgs 0]
        set argVals($positionalArg) $settingArgVal
        set procArgs [lreplace $procArgs 0 0]
    }
    
    # now do some error checking, to insure that all the fields
    # in the argVal array have been fully accounted for.
    foreach { key val} [array get argVals] {
        if { "<UNSET>" == $val } {
            puts "Error: argument $key not set in proc"
            return 0
        }
    }
    
    # success!!
    return 1
}
################################################################################
# This is the second definition of this proc in this file. And AFAIK it is
# the one actually used. ALSO - be warned that this code is replicated in 
# tcl_lint.tcl. So if you modify this code to change how we parse the
# meta comments, you also need to update that file. dm.
################################################################################
proc ::tclapp::support::args::parse_arg_usage_spec { argUsageSpec results } {
    # Summary: Returns 1 if the argument spec parsed out ok, 0 otherwise.
    
    # Argument Usage:
    # spec : a string which purports to hold an argument spec.
    # results : an array containing the results of parsing the argument spec
    
    # Return Value:
    # 1 is returned if we can recognize this as a well-formed argument spec
    # 0 is returned if we cannot recognize it as such.
    # 
    # If the function returns 1, then the following data are
    # communicated back to the caller via the "results" argument.
    # The following keys will have values set:
    # results(isOptional)    : 1 implies this is a spec for an optional argument
    # results(isPositional)  : 1 implies this is a spec for a positional argument,
    # results(isSwitch)      : 1 implies this is a boolean switch
    # results(defaultValue)  : if the spec indicates a default value for this
    #                        : argument, it is set to the indicated value.
    #                        : if there is no default, the value is <UNSET>
    # results(argName)       : a string which is the name of the argument
    # results(description)   : a string briefly describing the argument
    #
    # if the function returns 0, then the value of "results"
    # is undefined.
    
    # Categories:
    # system
    # non-user visible
    
    # enble pass-by-reference for the output arg
    upvar $results iResults
    # clear it out
    if { [array exists iResults] } {
        array unset iResults
    }
    
    if { [info exists iResults] } {
        unset iResults
    }
    
    # initialize to uninitialized :-)
    set iResults(isOptional)    {<UNSET>}
    set iResults(isPositional)  {<UNSET>}
    set iResults(isSwitch)      {<UNSET>}
    set iResults(defaultValue)  {<UNSET>}
    set iResults(argName)       {<UNSET>}
    set iResults(description)   {<UNSET>}
    
    # e.g. # [-report_name <arg> = report.txt] : when specified write a report to the specified name
    if { [regexp {[\s]*\[[\s]*-([^<]*)[\s]*\<arg\>[\s]*=[\s]*([^\]]*)\][\s]*:([^\n]*)} $argUsageSpec -> name def desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(defaultValue)  [string trim $def]
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-report_name <arg>] : when specified write a report to the specified name
    if { [regexp {[\s]*\[[\s]*-([^<]*)[\s]*\<arg\>[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-no_whammies] : when specified, don't allow whamies
    if { [regexp {[\s]*\[[\s]*-(no_[^:]*)[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      1
        set iResults(defaultValue)  1
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # [-use_smart_algorithm] : do it the good way, not the bad way
    if { [regexp {[\s]*\[[\s]*-([^:]*)[\s]*\][\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  0
        set iResults(isSwitch)      1
        set iResults(defaultValue)  0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g. # [pattern=*]     : Match cell names against patterns
    if { [regexp {[\s]*\[[\s]*([^=]*)=[\s]*([^\]]*)\][\s]*:([^\n]*)} $argUsageSpec -> name def desc] } {
        set iResults(isOptional)    1
        set iResults(isPositional)  1
        set iResults(isSwitch)      0
        set iResults(defaultValue)  [string trim $def]
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g.  # -report_name <arg> : write a report to the specified name
    if { [regexp {[\s]*[\s]*-([^<]*)[\s]*\<arg\>[\s]*[\s]*:([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    0
        set iResults(isPositional)  0
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    # e.g. # name : just a simple positional argument
    if { [regexp {[\s]*([^:]*):([^\n]*)} $argUsageSpec -> name desc] } {
        set iResults(isOptional)    0
        set iResults(isPositional)  1
        set iResults(isSwitch)      0
        set iResults(argName)       [string trim $name]
        set iResults(description)   [string trim $desc]
        return 1
    }
    
    return 0
}

proc ::tclapp::support::args::get_help_info_for_proc { procName results } {
    # Summary: populates an array "results" the documented help info for procedure "procName"
    
    # Argument Usage:
    # procName : name of a user-written app, including any namespaces (e.g. "::util::myApp")
    # results  : output array which contains key-value pairs holding the help info
    
    # Return Value:
    # The procedure returns 1 if the supplied procName has been documented
    # to the minimal degree enforced by the tcl linter.  It returns 0
    # otherwise--in which case the value of the "results" arg is undefined
    #
    # In addition, the procedure populates an array supplied by the
    # user (the "results" argument).  At the very minimum, if the
    # procedure returns "1" then the array will contain the following
    # key and value pairs:
    #
    # Key : {Summary}
    # Value : A one-line string which summarizes the functionality of the app
    #
    # Key : {Argument_Usage}
    # Value : A list of lists of the form:
    # {argName isPositional isOptional isSwitch defaultValue description}
    # where:
    #    "argName"       is the name of the argument
    #    "isPositional"  is true if this is a positional argument,
    #                    false otherwise
    #    "isOptional"    is true if this is an optional argument,
    #                    false otherwise
    #    "isSwitch"      is true if this is a non-positinal argument which
    #                    takes no argument, false otherwise
    #    "defaultValue"  the default value, if specified, <UNSET> otherwise
    #    "description"   a string of text which is a one-line description
    #                    of the argument
    #
    # Key : {Return_Value}
    # Value: A potentially multi-line string of text which describes the return
    #        value of the app
    #
    # 
    # Additionally, there may be the following additional key-value pairs,
    # if the user has more fully documented their app:
    #
    # Key   : {Categories}
    # Value : A list of tcl strings which are the categories under which
    #         this app might be classified
    #
    # Key : {Description:}
    # Value : A potentially multi-line string of text which describes in an
    #         exhaustive, detailed fashion what the app does and how to use it.
    #
    # Key   : {Examples}
    # Value : A potentially multi-line string of text which describes some
    #         examples of how to invoke the app on the command line and
    #         contexts of use.
    #
    # Key   : {See_Also}
    # Value : A list of other commands which are related to or provide ancilliary
    #         functionality to this command, and which the user might want or need
    #         to also know about in order to effectively use the app
    
    # Categories:
    # documentation
    
    
    # set up the return-by-ref array
    upvar $results iResults
    
    # clear it out
    if { [array exists iResults] } {
        array unset iResults
    }
    
    if { [info exists iResults] } {
        unset iResults
    }
    
    # get the proceedure's body
    set procBody [info body $procName]
    
    # now get the required sections:
    if { ! [get_documentation_section $procBody {Summary} buffer] } {
        return 0
    } else {
        set iResults(Summary) $buffer
    }
    
    if { ! [get_documentation_section $procBody {Argument Usage} buffer] } {
        return 0
    } else {
        # for convenience, we'll set the unparsed argument usage
        # (as it is in user-written text) here.  This is for
        # printing out wiki pages, etc.
        set iResults(Argument_Usage_Unparsed) $buffer
        
        # now parse them using the reading scheme
        set argUsageSpecs [string trim $buffer]
        set argUsageSpecs [split $argUsageSpecs "\n"]
        
        # this array maps each argument specified on the command line to
        # its value, as specified on the command line.  If any of the
        # values are "<UNSET>" then there is an error in the command line
        # parsing.
        set specList {}
        foreach argUsageSpec $argUsageSpecs {
            # parse the arg spec and extract the relevant info
            array unset pr
            array set pr {}
            if { [::tclapp::support::args::parse_arg_usage_spec $argUsageSpec pr] } {
                lappend specList \
                    "$pr(argName) $pr(isPositional) $pr(isOptional) $pr(isSwitch) $pr(defaultValue) \{$pr(description)\}"
            } else {
                return 0
            }
        }
        
        set iResults(Argument_Usage) $specList
    }
    
    if { ! [get_documentation_section $procBody {Return Value} buffer] } {
        return 0
    } else {
        set iResults(Return_Value) $buffer
    }
    
    # done with the required sections, now see if there are any optional sections
    
    if { [get_documentation_section $procBody {Categories} buffer] } {
        set outputCategories {}
        set categories [split $buffer ",\n"]
        foreach category $categories {
            set category [string trim $category]
            # if this is empty, don't add it
            if { {} == $category } { continue }
            
            lappend outputCategories $category
        }
        
        set iResults(Categories) $outputCategories
    }
    
    if { [get_documentation_section $procBody {Description} buffer] } {
        set iResults(Description) $buffer
    }
    
    if { [get_documentation_section $procBody {Examples} buffer] } {
        set iResults(Examples) $buffer
    }

    if { [get_documentation_section $procBody {See Also} buffer] } {
        set iResults(See_Also) $buffer
    }
    
    # success!!
    return 1
}


proc ::tclapp::support::args::get_documentation_section { procBody sectionName section } {
    # Summary : extracts the documentation section named $section from $body
    
    # Argument Usage :
    # procBody     : a string which is the body of a procedure
    # sectionName  : a string which names the section to be extracted
    # section      : if the section is found, $section contains the extracted text
    
    # Return Value:
    # returns 1 of the section was successfully found and extracts.
    #
    # If the function returns 1, then $section is populated with the extracted
    # section, stripped of the leading # on each line
    #
    # If the function returns 0, then $section is undefined.
    
    # Categories:
    # documentation
    # help system
    
    
    # pass the section by value
    upvar $section iSection
    
    if { [array exists iSections] } {
        array unset iSection
    }
    
    if { [info exists iSection] } {
        unset iSection
    }
    
    # initialize it to {}
    set iSection {}
    
    # prepair the search string
    set regExpString "\#\[ \\t\]*$sectionName\[ \\t\]*:\[ \\t\]*(\[^\\n\]*)\n"
    
    # find where the section starts
    if { ![regexp -indices $regExpString $procBody nspec pos] } {
        return 0
    }
    
    # Handle the stuff on the same line as the section tag:
    set firstLine [string range $procBody [lindex $pos 0] [lindex $pos 1]]
    if { "" != $firstLine } {
        append iSection "$firstLine\n"
    }
    
    set startSpecPos [expr [lindex $pos 1] + 2]
    
    # find where the section ends -- must end with two consecutive newlines
    if { ![regexp -start [lindex $nspec 0] -indices {\n[\s]*\n} $procBody pos] } {
        return 0
    }
    set endSpecPos [expr [lindex $pos 0] -1 ]
    
    # extract the text
    set buffer [string trim [string range $procBody $startSpecPos $endSpecPos]]
    
    # now see that each line is a comment line
    set lines [split $buffer "\n"]
    
    foreach line $lines {
        # just to make it easier to process
        set line [string trim $line]
        
        # all other lines but the first one must be 
        if { 0 != [string first "\#" $line ] } {
            return 0
        }
        
        # remove the space trailing the pound sign--if indeed it is a space
        if { 0==[string first "# " $line] } {
            set line [string range $line 2 end]
        } elseif { 0==[string first "#" $line] } {
            set line [string range $line 1 end]
        }
        
        # now append it to the output
        append iSection "$line\n"
    }
    
    # success!!
    return 1
}


proc ::tclapp::support::args::get_apps_for_category { categoryName results } {
    # Summary: query which user-written apps which belong to a category.
    
    # Argument Usage:
    # categoryName : a string which is the category we are querying for
    # results : array whose keys are app names and values are descriptions of the apps
    
    # Return Value:
    # the procedure returns no value.  Instead, it populates an array
    # supplied by the user (the "results" argument) such that:
    # the keys of the array are the names user supplied apps-fully qualified
    # as to their namespaces 
    # and the values are the summary description for the function
    # For example:
    # key   {::util::find_unsyncronized_paths}
    # value {Return a list of clock-domain crossing paths which lack a synchronizer}
    
    # Categories:
    # documenation
    # help system
    
    # set up the return-by ref array
    upvar $results iResults
    
    if { [array exists iResults] } {
        array unset iResults
    }
    
    if { [info exists iResults] } {
        unset iResults
    }
    
    
    # blow away any pre-existing stuffs
    array unset iResults
    
    # run through each proc, see if it has a "Categories" section
    foreach searchProc [userProcs] {

        set searchBody [info body $searchProc]
        if { ! [get_documentation_section $searchBody {Categories} sectionText] } {
            # has no category associated with it; just bail
            continue
        }
        
        # see if we match the category information
        if { ! [regexp $categoryName $sectionText] } {
            # don't match, just bail
            continue
        }
        
        # since we match, see if we've got a summry section
        # (should have, but just for robustness sake...)
        if { ! [get_documentation_section $searchBody {Summary} summaryText] } {
            continue
        }
        
        set iResults($searchProc) [string trim $summaryText]
    }
}

proc ::tclapp::support::args::get_all_app_categories {} {
    # Summary: returns a list of all known categories specified
    # for all proceedures
    
    # Argument Usage:
    
    # Return Value:
    # a list of all of the known categories for all user-written tcl apps
    
    # Categories: system, help system
    
    # run through each proc, see if it has a "Categories" section
    array set uniquifier {} 
    foreach searchProc [userProcs] {
        # get the body of this procedure
        set searchBody [info body $searchProc]
        
        # see if there is a "Categories" section documented
        if { ! [get_documentation_section $searchBody {Categories} sectionText] } {
            # has no category associated with it; just bail
            continue
        }

        # seperate and trim
        set categories [split $sectionText ",\n"]
        foreach category $categories {
            set category [string trim $category]
            
            # check to see if we've already collected this category
            if { [info exists uniquifier($category) ] } { continue }
            
            # don't include any null categories which may have snuck in
            if { {} == $category } { continue }
            
            # this is a category we've not seen before so note it
            set uniquifier($category) 1
        }
    }
    
    # tell it to the world
    return [array names uniquifier]
}


proc ::tclapp::support::args::get_help { procName } {
    # Summary: returns a dictonary containing the help info for procName
    
    # Argument Usage:
    # procName : name of a user-written app, including any namespaces (e.g. "::util::myApp")
    
    # Return Value:
    # This procedure populates dictionary supplied by the
    # user (the "results" argument).  At the very minimum, if the
    # procedure returns "1" then the dictionary will contain the following
    # key and value pairs:
    #
    # Key : {Summary}
    # Value : A one-line string which summarizes the functionality of the app
    #
    # Key    :  {Argument_Usage}
    # Value  :  A nested dictionary of the form:
    # argName position   -1 if non-positional arg, otherwise the ordinal position
    # argName isOptional 1/0  indicates whether this optional
    # argName isSwitch   1/0  indicates whether this is a switch
    # argName defaultValue <text> description of the argument
    #
    # Key : {Return_Value}
    # Value: A potentially multi-line string of text which describes the return
    #        value of the app
    #
    # 
    # Additionally, there may be the following additional key-value pairs,
    # if the user has more fully documented their app:
    #
    # Key   : {Categories}
    # Value : A list of tcl strings which are the categories under which
    #         this app might be classified
    #
    # Key : {Description:}
    # Value : A potentially multi-line string of text which describes in an
    #         exhaustive, detailed fashion what the app does and how to use it.
    #
    # Key   : {Examples}
    # Value : A potentially multi-line string of text which describes some
    #         examples of how to invoke the app on the command line and
    #         contexts of use.
    #
    # Key   : {See_Also}
    # Value : A list of other commands which are related to or provide ancilliary
    #         functionality to this command, and which the user might want or need
    #         to also know about in order to effectively use the app
    
    # Categories: documentation

    variable systemCategories
    
    set returner [dict create]
    
    # get the proceedure's body
    set procBody [info body $procName]
    
    # now get the required sections:
    if { ! [get_documentation_section $procBody {Summary} buffer] } {
        return -code error $returner
    } else {
        dict set returner {Summary} "(User-written application)\n$buffer"
    }
    
    if { ! [get_documentation_section $procBody {Argument Usage} buffer] } {
        return -code error $returner
    } else {
        # for convenience, we'll set the unparsed argument usage
        # (as it is in user-written text) here.  This is for
        # printing out wiki pages, etc.
        
        dict set returner {Argument_Usage_Unparsed} $buffer
        
        # now parse them using the reading scheme
        set argUsageSpecs [string trim $buffer]
        set argUsageSpecs [split $argUsageSpecs "\n"]
        
        # this array maps each argument specified on the command line to
        # its value, as specified on the command line.  If any of the
        # values are "<UNSET>" then there is an error in the command line
        # parsing.
        set pos 1
        foreach argUsageSpec $argUsageSpecs {
            # parse the arg spec and extract the relevant info
            array unset pr
            array set pr {}
            if { [::tclapp::support::args::parse_arg_usage_spec $argUsageSpec pr] } {
                if { $pr(isPositional) } {
                    dict set returner {Argument_Usage} $pr(argName) position $pos
                    incr pos
                } else {
                    dict set returner {Argument_Usage} $pr(argName) position -1
                }
                dict set returner {Argument_Usage} $pr(argName) isOptional    $pr(isOptional)
                dict set returner {Argument_Usage} $pr(argName) isSwitch      $pr(isSwitch)
                dict set returner {Argument_Usage} $pr(argName) defaultValue  $pr(defaultValue)
                dict set returner {Argument_Usage} $pr(argName) description   $pr(description)
            } else {
                return -code error $returner
            }
        }
    }
    
    if { ! [get_documentation_section $procBody {Return Value} buffer] } {
        return -code error $returner
    } else {
        dict set returner {Return Value} $buffer
    }
    
    # done with the required sections, now see if there are any optional sections
    
    if { [get_documentation_section $procBody {Categories} buffer] } {
        # we need to uniquify the categories
        set uniquifier [dict create]
        foreach category $buffer {
            set category [string trim $category]
            set category [string trim $category ","]
            
            # see if this is one of the system categories, if so bail
            if { [dict exists $systemCategories $category] } {
                continue;
            }
            
            # put it into the uniquifier
            dict set uniquifier $category 1
        }
        
        # every user-written app is also in the user-written category
        dict set uniquifier user-written 1
        
        dict set returner {Categories} [dict keys $uniquifier]
    }
    
    if { [get_documentation_section $procBody {Description} buffer] } {
        dict set returner {Description} $buffer
    }
    
    if { [get_documentation_section $procBody {Examples} buffer] } {
        dict set returner {Examples} $buffer
    }
    
    if { [get_documentation_section $procBody {See Also} buffer] } {
        dict set returner {See Also} $buffer
    }
    
    # success!!
    return -code ok $returner
}


proc ::tclapp::support::args::write_help_wiki { procName wikiPage } {
    # Summary: format procedure documention as a wiki page
    
    # Arguent Usage:
    # procName : format this procedure's documentation as wiki page
    # wikiPage : if 1 is returned, this is set to a formated wiki page
    
    # Return Value:
    # returns 0 if no documentaion could be found for
    # input procname.  Returns 1 if documentation could be find,
    # and sets $wikiPage to be a string which is the formatted wiki
    # page
    
    # Categories:
    # documentation
    # help system
    
    #--------------------------------------------------
    
    # set up the return-by-ref output variable
    upvar $wikiPage iWikiPage
    
    if { [array exists iWikiPage] } {
        array unset iWikiPage
    }
    
    if { [info exists iWikiPage] } {
        unset iWikiPage
    }

    
    # see if we can find help info for this proc
    if { ! [get_help_info_for_proc $procName docResults] } {
        # couldn't find help info, so bail
        return 0
    }
    
    # add verbaim wrapper for wiki formatting
    append iWikiPage "<verbatim>\n"
    
    # add the sumary
    if { [info exists docResults(Summary)] } {
        append iWikiPage "Summary: $docResults(Summary)"
        append iWikiPage "\n"
    }
    
    # add the argument usage section
    if { [info exists docResults(Argument_Usage_Unparsed)] } {
        # put header
        append iWikiPage "Argument Usage:\n"
        
        # insert spaces before each line
        set argSpecs [split $docResults(Argument_Usage_Unparsed) "\n"]
        foreach argSpec $argSpecs {
            # get rid of extranious spaces
            set argSpec [string trim $argSpec]
            append iWikiPage "    $argSpec\n"
        }
    }
    
    # add the Return Value section
    if { [info exists docResults(Categories)] } {
        # put header
        puts "cas= $docResults(Categories)"
        append iWikiPage "Categories: "
        set isFirst 1
        foreach category $docResults(Categories) {
            if { $isFirst } {
                set isFirst 0
            } else {
                append iWikiPage ", "
            }
            append iWikiPage "$category"
        }
        append iWikiPage "\n"
    }
    
    # close off verbaim wrapper for wiki formatting
    append iWikiPage "</verbaimt>\n"
    
    # success!!
    return 1
}

proc ::tclapp::support::args::get_undo_proc { procName } {
    # Summary: returns a dictonary containing the help info for procName
    
    # Argument Usage:
    # procName : name of a user-written app, including any namespaces (e.g. "::util::myApp")
    
    # Return Value:
    # string containing the proc name, if it exists, and code of 0
    # string containing "" if it doesn't exist, and a code of error
    
    # Categories: documentation
    
    # get the proceedure's body
    set procBody [info body $procName]
    
    # now get undo procedure name:
    if { ! [get_documentation_section $procBody {Undo proc} buffer] } {
        return -code error ""
    } 
    
    set procName "::"
    append procName [string trim $buffer]
    
    # see if this procedure is actually defined
    if { [info proc $procName] == $procName } {
        # if we've found the actual procedure, return it
        return -code 0 $procName
    } 
    
    
    # could not find it 
    return -code error ""
}

proc ::tclapp::support::args::get_redo_proc { procName } {
    # Summary: returns a dictonary containing the help info for procName
    
    # Argument Usage:
    # procName : name of a user-written app, including any namespaces (e.g. "::util::myApp")
    
    # Return Value:
    # string containing the proc name, if it exists, and code of 0
    # string containing "" if it doesn't exist, and a code of error
    
    # Categories: documentation
    
    # get the proceedure's body
    set procBody [info body $procName]
    
    # now get redo procedure name:
    if { ! [get_documentation_section $procBody {Redo proc} buffer] } {
        return -code error ""
    } 
    
    set procName "::"
    append procName [string trim $buffer]
    
    # see if this procedure is actually defined
    if { [info proc $procName] == $procName } {
        # if we've found the actual procedure, return it
        return -code 0 $procName
    } 
    
    
    # could not find it 
    return -code error ""
}

package provide ::tclapp::support::args 1.0
