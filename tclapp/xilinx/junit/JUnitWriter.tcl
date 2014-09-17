####################################################################################################
#
# JUnitWriter.tcl (xml writer utilities for junit)
#
# Script created on 01/31/2014 by Nik Cimino (Xilinx, Inc.)
#
# 2014 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################################
# 
# Procedures:     format_junit
#                 graph_to_xml
#                 write
# Dependencies:   ::struct::graph
#                 ::struct::stack
#                 
####################################################################################################

####################################################################################################
# title: JUnit Reporting API
####################################################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::junit {

####################################################################################################
# section: writer 
####################################################################################################

namespace export format_junit
namespace export graph_to_xml
namespace export write


proc format_junit { _dataGraph } {
  # Summary:
  # Converts the results of the in-memory data object to JUnit.
  #
  # This conversion process is in place to handle conversion to different output types.
  # This is a JUnit package, and thus it would be more ideal to make the data graph a 
  # 1:1 mapping with the junit xml graph.
  #
  # Conceptually: The JUnit package works with a 'data graph'/results object in memory.
  # Before we dump to disk, this method is called to build a 'junit graph' that will 
  # map information from the 'data graph' to the best matching 'junit graph' node/field.
   
  # Argument Usage: 
  #   dataGraph : The Data Graph to convert to a JUnit Graph.
   
  # Return Value:
  # Returns the JUnit Graph.
    
  # Categories: xilinxtclstore, junit
 
  # !! this section of code can be confusing, proceed with caution !!

  # reset the jUnitGraph if it exists
  set jUnitGraph ::tclapp::xilinx::junit::junit_graph
  if { "[ info command $jUnitGraph ]" == "$jUnitGraph" } {
    $jUnitGraph destroy
  }
  
  # (re-)build new/empty jUnitGraph
  ::struct::graph $jUnitGraph
  
  # find root node of dataGraph ("testsuites")
  set data_root [ $_dataGraph nodes -filter ::tclapp::xilinx::junit::is_root_node ]
  set junit_root [ add_node $jUnitGraph "testsuites" ]

  # iterate over all of the testsuite nodes (the outs from the root)
  foreach data_ts [ $_dataGraph nodes -out $data_root ] {
    
    # extract and convert testsuite attrs
    set attrs {}
    lappend attrs [ list name [ $_dataGraph node get $data_ts name ] ]              ; # name -> name
    lappend attrs [ list timestamp [ $_dataGraph node get $data_ts starttime ] ]    ; # starttime -> timestamp
    lappend attrs [ list hostname [ $_dataGraph node get $data_ts hostname ] ]      ; # hostname -> hostname
    
    # add the node testsuite to the jUnitGraph
    set junit_ts [ add_node $jUnitGraph "testsuite" $attrs {} $junit_root ]
    
    # iterate over all of the testcase, stdout, or stderr nodes (the outs from the testsuite)
    foreach data_tc_std [ $_dataGraph nodes -out $data_ts ] {
      
      # extract and convert testcase, stdout, or stderr attrs
      ## 'type' defines the xml tagname in this context - used for all 3 ( testcase, stdout, stderr)
      set attrs {}
      set type [ $_dataGraph node get $data_tc_std type ]                           ; # type -> type
      set content {}

      if { "$type" == "testcase" } {
        
        # extract and convert - testcase only attrs
        lappend attrs [ list classname [ $_dataGraph node get $data_tc_std group ] ]; # group -> classname
        lappend attrs [ list name [ $_dataGraph node get $data_tc_std name ] ]      ; # name -> name
        lappend attrs [ list time [ $_dataGraph node get $data_tc_std walltime ] ]  ; # walltime -> time

      } else { 
        
        # extract and convert - stdout or stderr only attrs
        ## 'content' defines the xml content in this context
        set content [ $_dataGraph node get $data_tc_std content ]                   ; # content -> content

      }
      
      # add testcase, stdout, or stderr node
      set junit_tc [ add_node $jUnitGraph $type $attrs $content $junit_ts ]
      
      # iterate over all of the status messages nested within testcase
      foreach data_status [ $_dataGraph nodes -out $data_tc_std ] {
        
        # extract and convert error or failure nodes to junit nodes
        ## 'content' defines the xml content in this context
        set tagname [ $_dataGraph node get $data_status type ]
        set attrs {}
        lappend attrs [ list message [ $_dataGraph node get $data_status message ] ]; # message -> message
        set content [ $_dataGraph node get $data_status content ]

        # add error or failure node
        set junit_status [ add_node $jUnitGraph $tagname $attrs $content $junit_tc ]

      }; # foreach on data_status - handles error, failure nodes

    }; # foreach on data_tc_std - handles testcase, stdout, stderr nodes

  }; # foreach on data_ts - handles testsuite nodes

  return $jUnitGraph
}


proc graph_to_xml { _graph { _rootnodes {} } } {
  # Summary:
  # Converts a struct::graph object directly to xml.
  
  # Argument Usage: 
  #   graph : The output content to go into the file.
  #   rootnodes : The nodes to start with, else all root nodes are used.
   
  # Return Value:
  # XML from graph.
    
  # Categories: xilinxtclstore, junit
 
  set delimiter "\n"
  set xml {}
  if { $_rootnodes == {} } {
    set _rootnodes [ $_graph nodes -filter ::tclapp::xilinx::junit::is_root_node ]
    lappend xml {<?xml version="1.0" encoding="UTF-8"?>}
    lappend xml "<!-- Generated by Xilinx JUnit App version [ lindex [ package versions ::tclapp::xilinx::junit ] 0 ] on [ clock format [ clock seconds ] ] -->"
  }
  foreach root $_rootnodes {
    lappend xml [ node_to_xml $_graph $root ]
  }
  return [ join $xml $delimiter ]
}


proc write { _outputContent { _filename "test.xml" } } {
  # Summary:
  # Write out the output content to a file.
  
  # Argument Usage: 
  #   outputContent : The output content to go into the file.
  #   filename : Write the output contents to filename.
   
  # Return Value:
    
  # Categories: xilinxtclstore, junit
 
  set fh [ open $_filename "w+" ]
  puts $fh $_outputContent
  close $fh
}


proc add_node { _graph _name { _attrs {} } { _content {} } { _parent {} }} {
  # Summary:
  # Adds a node to a graph.
  
  # Argument Usage: 
  #   graph : Graph is used to store the node.
  #   name : Node name.
  #   attrs : Node attrs (key value pair list).
  #   content : Content of the node, {} means empty.
  #   parent : The parent node to add this node to.
   
  # Return Value:
  # The newly created node.
    
  # Categories: xilinxtclstore, junit
 
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


proc node_to_xml { _graph _node } {
  # Summary:
  # Converts a regular graph node into XML.
  # The node's keys are used to populate XML data, keys are:
  #   tagname = tag name <tagname...>
  #   attrs = attributes on node <tagname attr1="val1" ...>
  #   content = content of node
  #     <tagname attr1="val1" ...>content</tagname>
  #       else
  #     <tagname attr1="val1" .../>
  
  # Argument Usage: 
  #   graph : Graph is used to retrieve node.
  #   node : Node is converted to XML.
   
  # Return Value:
  # The XML generated for the provided node.
    
  # Categories: xilinxtclstore, junit
 
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


proc attrs_to_string { _attrs } {
  # Summary:
  # Converts a list of key value pairs into a string of attributes.
  
  # Argument Usage: 
  #   attrs : A list of key value pairs.
   
  # Return Value:
  # A string of the key value pairs.
    
  # Categories: xilinxtclstore, junit
 
  set string ""
  foreach attr $_attrs {
    lappend string " [ xml_escape [ lindex $attr 0 ] ]=\"[ xml_escape [ lindex $attr 1 ] ]\""
  }
  return [ join $string "" ]
}


proc xml_escape { _string } {
  # Summary:
  # Escapes all XML characters.
  #   & = &amp;
  #   " = &quot;
  #   ' = &apos;
  #   < = &lt;
  #   > = &gt;
  
  # Argument Usage: 
  #   string : String to escape
   
  # Return Value:
  # The escaped version of the input string.
    
  # Categories: xilinxtclstore, junit
 
  set output $_string
  set output [ string map {& &amp;} $output ]
  set output [ string map {\" &quot;} $output ]
  set output [ string map {' &apos;} $output ]
  set output [ string map {< &lt;} $output ]
  set output [ string map {> &gt;} $output ]
  return $output
}


proc is_root_node { _graph _node } {
  # Summary:
  # Filter used to return the root node.
  
  # Argument Usage: 
  #   graph : Graph object is passed in by the filter.
  #   node : Node object is passed in by the filter.
   
  # Return Value:
  # Return true if the node has zero ins (must be root).
    
  # Categories: xilinxtclstore, junit
 
  return [ expr [ $_graph node degree -in $_node ] == 0 ]
}

}; # namespace ::tclapp::xilinx::junit
