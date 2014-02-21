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
set combineGraph    ::tclapp::xilinx::junit::combineGraph
set combinedGraph   ::tclapp::xilinx::junit::combinedGraph


####################################################################################################
# section: parser
####################################################################################################

namespace export xml_to_graph
namespace export combine_junit


proc combine_junit { _files _outputFile } {
  variable combineGraph
  variable combinedGraph
  if { "[ info command $combinedGraph ]" == "$combinedGraph" } {
    $combinedGraph destroy
  }
  if { "[ info command $combineGraph ]" == "$combineGraph" } {
    $combineGraph destroy
  }
  ::struct::graph $combinedGraph
  set new_root_node [ add_node $combinedGraph "testsuites" ]
  foreach xmlFile $_files {
    set fh [ open $xmlFile "r" ]
    set data [ read $fh ]
    ::struct::graph $combineGraph
    xml_to_graph $combineGraph $data
    set old_root_node [ $combineGraph nodes -filter ::tclapp::xilinx::junit::is_root_node ]
    set ts_node [ $combineGraph nodes -out $old_root_node ]
    set new_data [ $combineGraph serialize $ts_node ]
    puts "serialized:\n$new_data"
    $combineGraph destroy
  }
}


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
      set attrs [ string_to_attrs $attrsString ]
      set content [ eval "{[ string trim $content ]}" == "{}" ? "{}" : $content ]
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
      set attrs [ string_to_attrs $attrsString ]
      set content [ eval "{[ string trim $content ]}" == "{}" ? "{}" : [ xml_expand $content ] ]
      set parent [ $parserStack peek ] 
      $parserStack push [ add_node $_graph $tagname $attrs $content $parent ]
    }
  }

  return $_graph
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
proc xml_expand { _string } {
  set output $_string
  set output [ string map {&gt; >} $output ]
  set output [ string map {&lt; <} $output ]
  set output [ string map {&apos; '} $output ]
  set output [ string map {&quot; \"} $output ]
  set output [ string map {&amp; &} $output ]
  return $output
}


}; # namespace ::tclapp::xilinx::junit

