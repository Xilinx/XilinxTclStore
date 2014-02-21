####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   01/31/14
# Script name:    JUnitWriter.tcl
# Procedures:     format_junit
#                 graph_to_xml
#                 write
# Tool Versions:  Vivado 2013.4
# Description:    JUnit Reporting API
# Dependencies:   ::struct::graph
#                 ::struct::stack
#                 
# Notes:          
#     ?
# 
# Getting Started:
#     % package require ::tclapp::xilinx::junit
#     % ?
#
####################################################################################################

####################################################################################################
# title: JUnit Reporting API
####################################################################################################

namespace eval ::tclapp::xilinx::junit {


####################################################################################################
# section: variables
####################################################################################################

set parserStack     ::tclapp::xilinx::junit::parserStack


####################################################################################################
# section: parser
####################################################################################################

namespace export xml_to_graph


# proc: xml_to_graph
# Summary:
# 
#
# Argument Usage: 
#:    graph_to_xml _graph ?_rootnodes?
# 
# Parameters:
#     _graph         - The output content to go into the file
#     _rootnodes     - Write the output contents to filename
# 
# Return Value:
#     xml            - XML from graph
# 
# Example:
#     
#:     # converts and generates XML
#:     puts [ graph_to_xml graph [ format_junit graph ] ]
#
proc xml_to_graph { _graph _xmlData } {
  variable parserStack
  # validate graph object 
  if { "[ info command $_graph ]" != "$_graph" } {
    error "failed to find graph: '$_graph'"
  }
  # clean and rebuild a fresh stack
  if { "[ info command $parserStack ]" == "$parserStack" } {
    $parserStack destroy
  }
  ::struct::stack $parserStack
  set nodeStarts [ split $_xmlData '<' ]
  foreach nodeStart $nodeStarts {
    if { "$nodeStart" == "" } { continue }
    # schemas and comments are ignored
    if { [ regexp {\?.*} $nodeStart ] } { continue }
    if { [ regexp {\!--.*} $nodeStart ] } { continue }
    # parse tags
    if { [ regexp {/(.*)} $nodeStart match tagArgs content ] } { 
      # go to parent node
      if { [ catch { $parserStack pop } returned ] } { error "Poorly formed XML - found extra terminate tag" }
    } elseif { [ regexp {(.*)/>(.*)} $nodeStart match tagArgs content ] } { 
      # add, but don't push
      set tagname [ lindex $tagArgs 0 ]
      set attrsString [ lrange $tagArgs 1 end ]
      set attrs [ string_to_attrs $attrString ]
      set content [ eval "[ string trim $content ]" == "" ? "" : $content ]
      set parent [ $parserStack peek ] 
      add_node $_graph $tagname $attrs $content $parent
      #puts "match : $match"; 
      #puts "tagArgs : $tagArgs" ; 
      #puts "tag : [ lindex $tagArgs 0 ]"; 
      #puts "attrs : [ join [ lrange $tagArgs 1 end ] { } ]"; 
      #puts "content : {[ string trim $content ]}"
    } elseif { [ regexp {(.*)>(.*)} $nodeStart match tagArgs content ] } { 
      # add, and push
      set tagname [ lindex $tagArgs 0 ]
      set attrsString [ lrange $tagArgs 1 end ]
      set attrs [ string_to_attrs $attrString ]
      set content [ eval "[ string trim $content ]" == "" ? "" : [ xml_expand $content ] ]
      set parent [ $parserStack peek ] 
      $parserStack push [ add_node $_graph $tagname $attrs $content $parent ]
    }
  }

  return $_graph
}

proc string_to_attrs { _string } {
  set stringList [ join $_string { } ]
  set attrs {}
  foreach stringItem $stringList {
    if { [ regexp {(.*)="(.*)"} $stringItem match key value ] } {
      lappend attrs [ list $key [ xml_expand $value ] ]
    } else {
      error "Poorly formed XML - bad attribute formatting"
    }
  }
  return $attrs
}

proc xml_expand { _string } {
  set output $_string
  set output [ string map {&gt; >} $output ]
  set output [ string map {&lt; <} $output ]
  set output [ string map {&apos; '} $output ]
  set output [ string map {&quot; \"} $output ]
  set output [ string map {&amp; &} $output ]
  return $output
}

# proc: write
# Summary:
# Write out the output content to a file
#
# Argument Usage: 
#:     add_node _outputContent ?_filename?
# 
# Parameters:
#     _outputContent - The output content to go into the file
#     _filename      - Write the output contents to filename
# 
# Return Value:
#     void           - Unusued
# 
# Example:
#     
#:     # creates and adds node
#:     write $content "report.xml"
#
proc write { _outputContent { _filename "test.xml" } } {
  set fh [ open $_filename "w+" ]
  puts $fh $_outputContent
  close $fh
}


# proc: add_node
# Summary:
# Adds a node to a graph
#
# Argument Usage: 
#:     add_node _graph _name ?_attrs? ?_content? ?_parent?
# 
# Parameters:
#     _graph         - Graph is used to store the node
#     _name          - Node name 
#     _attrs         - Node attrs (key value pair list)
#     _content       - Content of the node, {} means empty
#     _paremt        - The parent node to add this node to
# 
# Return Value:
#     node           - The newly created node
# 
# Example:
#     
#:     # creates and adds node
#:     set node [ add_node graph "testsuite" {{name "Synthesis"}} {} $testsuites
#
proc add_node { _graph _name { _attrs {} } { _content {} } { _parent {} }} {
  set node [ $_graph node insert ]
  $_graph node set $node tagname $_name
  if { [ llength $_attrs ] > 0 } {
    $_graph node set $node attrs $_attrs
  }
  if { "$_content" != "" } {
    $_graph node set $node content $_content
  }
  if { "$_parent" != "" } {
    $_graph arc insert $_parent $node
  }
  return $node
}


# proc: node_to_xml
# Summary:
# Converts a regular graph node into XML
# The node's keys are used to populate XML data, keys are:
#   tagname = tag name <tagname...>
#   attrs = attributes on node <tagname attr1="val1" ...>
#   content = content of node
#     <tagname attr1="val1" ...>content</tagname>
#       else
#     <tagname attr1="val1" .../>
#
# Argument Usage: 
#:     node_to_xml _graph _node
# 
# Parameters:
#     _graph         - Graph is used to retrieve node
#     _node          - Node is converted to XML
# 
# Return Value:
#     xml            - The XML generated for the provided node
# 
# Example:
#     
#:     # converts the graph node into XML
#:     set xml [ node_to_xml graph $node ]
#
proc node_to_xml { _graph _node } {
  set tagname [ $_graph node get $_node tagname ]
  set attrsStr {}
  if { [ $_graph node keyexists $_node attrs ] } {
    set attrs [ $_graph node get $_node attrs ]
    set attrsStr [ attrs_to_string $attrs ]
  }
  set children [ $_graph nodes -out $_node ]
  set singleTag [ expr ( ! [ $_graph node keyexists $_node content ] ) && ( [ llength $children ] == 0 ) ] 
  if { $singleTag } {
    return "<${tagname}${attrsStr}/>"
  }

  set xml {}
  lappend xml "<${tagname}${attrsStr}>"
  if { [ $_graph node keyexists $_node content ] } {
    lappend xml [ xml_escape [ $_graph node get $_node content ] ]
  }
  foreach child $children {
    lappend xml [ node_to_xml $_graph $child ]
  }
  lappend xml "</${tagname}>"
  return [ join $xml "\n" ]
}


# proc: attrs_to_string
# Summary:
# Converts a list of key value pairs into a string of attributes
#
# Argument Usage: 
#:     attrs_to_string _attrs
# 
# Parameters:
#     _attrs         - A list of key value pairs
# 
# Return Value:
#     string         - A string of the key value pairs
# 
# Example:
#     
#:     # converts the graph node into XML
#:     set attrs { {name "test"} {enabled 0} }
#:     set attrString [ node_to_xml graph $node ]
#:     puts $attrString
#:     # name="test" enabled="0"
#
proc attrs_to_string { _attrs } {
  set string ""
  foreach attr $_attrs {
    lappend string " [ xml_escape [ lindex $attr 0 ] ]=\"[ xml_escape [ lindex $attr 1 ] ]\""
  }
  return [ join $string "" ]
}


# proc: xml_escape
# Summary:
# Escapes all XML characters
#   & = &amp;
#   " = &quot;
#   ' = &apos;
#   < = &lt;
#   > = &gt;
#
# Argument Usage: 
#:     is_root_node _graph _node
# 
# Parameters:
#     _string        - String to escape
# 
# Return Value:
#     output         - The escaped version of the input string
# 
# Example:
#     
#:     # returns the root nodes of graph
#:     set escaped [ xml_escape {"The beginning & the <empty>"} ]
#:     puts $escaped
#:     # &quot;The beginning &amp; the &lt;empty&gt;&quot;
#
proc xml_escape { _string } {
  set output $_string
  set output [ string map {& &amp;} $output ]
  set output [ string map {\" &quot;} $output ]
  set output [ string map {' &apos;} $output ]
  set output [ string map {< &lt;} $output ]
  set output [ string map {> &gt;} $output ]
  return $output
}


# proc: is_root_node
# Summary:
# Filter used to return the root node
#
# Argument Usage: 
#:     is_root_node _graph _node
# 
# Parameters:
#     _graph         - Graph object is passed in by the filter
#     _node          - Node object is passed in by the filter 
# 
# Return Value:
#     returned       - Return true if the node has zero ins (must be root)
# 
# Example:
#     
#:     # returns the root nodes of graph
#:     set data_root [ graph nodes -filter ::tclapp::xilinx::junit::is_root_node ]
#
proc is_root_node { _graph _node } {
  return [ expr [ $_graph node degree -in $_node ] == 0 ]
}

}; # namespace ::tclapp::xilinx::junit


####################################################################################################
# JUnitXML schema = JUnit test result schema for the Apache Ant JUnit and JUnitReport tasks 
# Copyright © 2011, Windy Road Technology Pty. Limited The Apache Ant JUnit XML Schema is distributed 
# under the terms of the GNU Lesser General Public License (LGPL) 
# http://www.gnu.org/licenses/lgpl.html Permission to waive conditions of this license may be 
# requested from Windy Road Support (http://windyroad.org/support).
#   http://windyroad.com.au/dl/Open%20Source/JUnit.xsd
#   http://www.w3schools.com/schema/el_simpletype.asp
####################################################################################################
# ISO8601_DATETIME_PATTERN = [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}
# pre-string = string 
#   attr: whiteSpace = preserve
# testsuites = Contains an aggregation of testsuite results
# -| testsuite(0-n) = Contains the results of exexuting a testsuite
# -|   attr: name token(1) = Full class name of the test for non-aggregated testsuite documents. Class name without the package for aggregated testsuites documents
# -|   attr: timestamp ISO8601_DATETIME_PATTERN = When the test was executed. Timezone may not be specified.
# -|   attr: hostname token(1) = Host on which the tests were executed. 'localhost' should be used if the hostname cannot be determined.
# -|   attr: tests int = The total number of tests in the suite
# -|   attr: failures int = The total number of tests in the suite that failed. A failure is a test which the code has explicitly failed by using the mechanisms for that purpose. e.g., via an assertEquals
# -|   attr: errors int = The total number of tests in the suite that errorrd. An errored test is one that had an unanticipated problem. e.g., an unchecked throwable; or a problem with the implementation of the test.
# -|   attr: time decimal = Time taken (in seconds) to execute the tests in the suite
# ---| properties = Properties (e.g., environment settings) set during test execution
# -----| property 
# -----|   attr: name token(1)
# -----|   attr: value string
# ---| testcase(0-n) 
# ---|   attr: classname token(1) = Full class name for the class the test method is in.
# ---|   attr: name token(1) = Name of the test method
# ---|   attr: time decimal = Time taken (in seconds) to execute the test
# -----| error = Indicates that the test errored. An errored test is one that had an unanticipated problem. e.g., an unchecked throwable; or a problem with the implementation of the test. Contains as a text node relevant data for the error, e.g., a stack trace
# -----|   content: pre-string 
# -----|   attr: message string = The error message. e.g., if a java exception is thrown, the return value of getMessage()
# -----|   attr: type string = The type of error that occured. e.g., if a java execption is thrown the full class name of the exception.
# -----| failure = Indicates that the test failed. A failure is a test which the code has explicitly failed by using the mechanisms for that purpose. e.g., via an assertEquals. Contains as a text node relevant data for the failure, e.g., a stack trace
# -----|   content: pre-string 
# -----|   attr: message string = The message specified in the assert
# -----|   attr: type string = The type of the assert.
# ---| system-out = Data that was written to standard out while the test was executed
# ---|   content: pre-string
# ---| system-err = Data that was written to standard error while the test was executed
# ---|   content: pre-string
####################################################################################################:
