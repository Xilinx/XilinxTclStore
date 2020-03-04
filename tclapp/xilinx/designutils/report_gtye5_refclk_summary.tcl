# tclapp/mycompany/myapp/myapp.tcl
package require Vivado 1.2019.1


namespace eval ::tclapp::xilinx::designutils {
  namespace export report_gtye5_refclk_summary
} 

#######################################################################################################
##
## Company:        Xilinx, Inc.
## Created by:     Kartheek Boddireddy 
##
## Version:        1.0
## Description:    This package generates reference clock summary of gt_quad_base IP based, IPI designs 
##
## BASIC USAGE:
## ============
##
## 1- Generates reference clock summary of gt_quad_base IP based, IPI designs
##
##   Vivado% xilinx::designutils::report_gtye5_refclk_summary
##   2020.03.03 - Initial release
##
##########################################################################################################
# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils {
  namespace export report_gtye5_refclk_summary
} ]

proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary {args} {
  # Summary: 
  # Generates reference clock summary of gt_quad base IP based, IPI block design
  # Command to generate the summary is
  #                    xilinx::designutils::report_gtye5_refclk_summary


  # Argument Usage:
  # Return Value:


  # No Arguments needed, the only requirement for the script is the block design should be opened and it should be gt_quad based bd design
  # file wll be generated with the name <bd_name>_gtye5_refclk_summary.txt


  # Categories: Xilinxtclstore, designutils
  #-------------------------------------------------------

   ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::generate_report_gtye5_refclk_summary

   return 0
}


#namespace eval ::tclapp::xilinx::designutils::report_gtye5_refclk_summary {
#  namespace export report_gtye5_refclk_summary
#} 

eval [list namespace eval ::tclapp::xilinx::designutils::report_gtye5_refclk_summary {
  namespace export generate_report_gtye5_refclk_summary
} ]

#namespace eval ::tclapp::xilinx::designutils::report_gtye5_refclk_summary {

proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::generate_report_gtye5_refclk_summary {args} {

  # Summary: 
  # Generates reference clock summary of gt_quad base IP based, IPI block design
  # Command to generate the summary is
  #                    xilinx::designutils::report_gtye5_refclk_summary


  # Argument Usage:
  # Return Value:


  # No Arguments needed, the only requirement for the script is the block design should be opened and it should be gt_quad based bd design
  # file wll be generated with the name <bd_name>_gtye5_refclk_summary.txt


  # Categories: Xilinxtclstore, designutils
  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set show_help 0
  set method [lshift args]
  switch -regexp -- $method {
    {^-help$} -
    {^-h(e(lp?)?)?$} -
    {^-usage$} -
    {^-u(s(a(ge?)?)?)?$} {
      incr show_help
    }
  }
  if {$show_help} {
    # <-- HELP
    puts [format {
      Usage: report_gtye5_refclk_summary
                  [-u|-usage|-h|-help]     - This help message
                  default/no argument      - Generates GTYE5_REFCLOCK Summary in gt_quad_base IP based, IPI block designs
      } ]
    # HELP -->
    return ""
    
  }

       

set proj [get_projects]
set pathk [get_property DIRECTORY [current_project]]

set refClkDict [dict create]
set bd_dk [current_bd_design]
set done [file mkdir $pathk\/GTREFCLK_SUMMARY]   
set file_name "$pathk\/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt"
set file_name1 "$pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt"
   set quad_cell_l ""
   set quadList ""

    
    set vlnv_qb [get_latest_vlnv]
    if { $vlnv_qb ne "" } {
     EvalSubstituting {vlnv_qb} {
     set quad_cell_l [get_bd_cells -hier -quiet -filter {vlnv == $vlnv_qb}]
     set quadList [split $quad_cell_l " "]
     } 0
    }


    if { $quad_cell_l eq ""} {
       puts "ERROR: There is no gt_quad_base IP in the design. Script is valid only for gt_quad_base IP based IPI designs"
       if { [file exists $file_name1] == 1} {
         set done [export_ip_user_files -of_objects  [get_files $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt] -no_script -reset -force -quiet]
         set done [remove_files  $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt]
         set done [file delete -force $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt]
        }
    } else {
       if { [file exists $file_name1] == 1} {
         set done [export_ip_user_files -of_objects  [get_files $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt] -no_script -reset -force -quiet]
         set done [remove_files  $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt]
         set done [file delete -force $pathk\/$proj.srcs/sources_1/imports/GTREFCLK_SUMMARY\/$bd_dk\_gtye5_refclk_summary.txt]
        }
        set outfilek [open $file_name w]

        puts $outfilek "===================================  GTYE5_REFCLOCK Summary Table ==================================="

        puts $outfilek "  "
        set tbl1 [::designutils::prettyTable_int]
        set heading [list S.No. {GTYE5_REFCLOCK Name} Freq ParentIP {REFCLK Source}]
        $tbl1 header $heading
        set snumk 0
        foreach quadCell $quadList {
          set txIntfcs [list ]
          set rxIntfcs [list ]
          
          set txIntfcPIDs [list ]
          set rxIntfcPIDs [list ]
        
          set quadIntcs [get_bd_intf_pins -quiet ${quadCell}/* -filter "VLNV=~ xilinx.com:interface:gt_tx_interface_rtl:1.0"]

           foreach quadIntfc $quadIntcs {
              set intf_net [get_bd_intf_nets -quiet -of_objects $quadIntfc]
              if { $intf_net eq "" } {
                lappend txIntfcs $quadIntfc
              } else {
                lappend txIntfcs [find_connected_pin $quadIntfc]
                lappend txIntfcPIDs [find_connected_core $quadIntfc]
              }
            }
          
          set quadIntcs [get_bd_intf_pins -quiet ${quadCell}/* -filter "VLNV=~ xilinx.com:interface:gt_rx_interface_rtl:1.0"]
          foreach quadIntfc $quadIntcs {
            set intf_net [get_bd_intf_nets -quiet -of_objects $quadIntfc]
             if { $intf_net eq "" } {
               lappend rxIntfcs $quadIntfc
             } else {
               lappend rxIntfcs [find_connected_pin $quadIntfc]
               lappend rxIntfcPIDs [find_connected_core $quadIntfc]
             }
           }
 
          set LANE_SEL_DICT "" 
          set settings_string [evaluate_bd_properties {*}$txIntfcs {*}$rxIntfcs]
          set LANE_SEL_DICT [dict create] 
          dict lappend LANE_SEL_DICT [dict get $settings_string RX0_LANE_SEL] RX0   
          dict lappend LANE_SEL_DICT [dict get $settings_string RX1_LANE_SEL] RX1  
          dict lappend LANE_SEL_DICT [dict get $settings_string RX2_LANE_SEL] RX2  
          dict lappend LANE_SEL_DICT [dict get $settings_string RX3_LANE_SEL] RX3  
          dict lappend LANE_SEL_DICT [dict get $settings_string TX0_LANE_SEL] TX0  
          dict lappend LANE_SEL_DICT [dict get $settings_string TX1_LANE_SEL] TX1  
          dict lappend LANE_SEL_DICT [dict get $settings_string TX2_LANE_SEL] TX2  
          dict lappend LANE_SEL_DICT [dict get $settings_string TX3_LANE_SEL] TX3 
          set keys_lsk [dict keys $LANE_SEL_DICT]
          set prot_num [llength $keys_lsk]
          set ref_clk_d [get_property CONFIG.REFCLK_STRING [get_bd_cells ${quadCell}]]
          set REFCLK_EXTERNAL_CONNECT                    [dict values $ref_clk_d]
          set REFCLK_EXTERNAL_CONNECT_UNIQUE             [uniquify_list $REFCLK_EXTERNAL_CONNECT]
          set NO_OF_REFCLK_EXTERNAL_CONNECT              [llength $REFCLK_EXTERNAL_CONNECT_UNIQUE ]
          set temp_cnt 0
          set ref_clk_src ""
          for {set n 0} {$n < $NO_OF_REFCLK_EXTERNAL_CONNECT } {incr n} {  
           set temp_cnt [expr $temp_cnt+1]
           set temp [lindex $REFCLK_EXTERNAL_CONNECT_UNIQUE $n] 
           set freq_val [string map {"\_unique6" ""} [string map {"\_unique5" ""} [string map {"\_unique4" ""} [string map {"\_unique3" ""} [string map {"\_unique2" ""} [string map {"\_unique1" ""} [string map {"\_MHz" ""} [string map {"PROT0_" ""} [string map {"PROT1_" ""} [string map {"PROT2_" ""} [string map {"PROT3_" ""} [string map {"PROT4_" ""} [string map {"PROT5_" ""} [string map {"PROT6_" ""} [string map {"PROT7_" ""} [string map {"refclk_" ""} [string map {"R0_" ""} [string map {"R1_" ""} [string map {"R2_" ""} [string map {"R3_" ""} [string map {"R4_" ""} [string map {"R5_" ""} $temp ]]]]]]]]]]]]]]]]]]]]]] 
           if {[string match "*multiple*" $freq_val]} { 
           set multiple_freq_type [string map {"\_unique6" ""} [string map {"\_unique5" ""} [string map {"\_unique4" ""} [string map {"\_unique3" ""} [string map {"\_unique2" ""} [string map {"\_unique1" ""} [string map {"\_MHz" ""}  [string map {"refclk_" ""} [string map {"\_ext_freq" ""} [string map {"multiple_" ""} $temp ]]]]]]]]]] 
           set multiple_freq_prot_type [string map {"\_unique6" ""} [string map {"\_unique5" ""} [string map {"\_unique4" ""} [string map {"\_unique3" ""} [string map {"\_unique2" ""} [string map {"\_unique1" ""} [string map {"\_MHz" ""}  [string map {"refclk_" ""} [string map {"\_ext_freq" ""} [string map {"multiple_" ""} [string map {"\_R0" ""} [string map {"\_R1" ""} [string map {"\_R2" ""} [string map {"\_R3" ""} [string map {"\_R4" ""} [string map {"\_R5" ""} $temp ]]]]]]]]]]]]]]]] 
           set multi_freq_port_name [string map {"\_unique6" ""} [string map {"\_unique5" ""} [string map {"\_unique4" ""} [string map {"\_unique3" ""} [string map {"\_unique2" ""} [string map {"\_unique1" ""} [string map {"\_MHz" ""}  [string map {"refclk_" ""} [string map {"\_ext_freq" ""} [string map {"multiple_" ""} [string map {"\PROT0_" ""} [string map {"\PROT1_" ""} [string map {"\PROT2_" ""} [string map {"\PROT3_" ""} [string map {"\PROT4_" ""} [string map {"\PROT5_" ""} [string map {"\PROT6_" ""} [string map {"\PROT7_" ""} $temp ]]]]]]]]]]]]]]]]]] 
            set snumk [expr $snumk+1]
            set list_AK0 [list $snumk]
            set ref_name $quadCell\/GT_REFCLK$n   
            set ref_clk_src [find_connected_core $ref_name]
            lappend list_AK0 $ref_name
            lappend list_AK0 "multiple"
            set prot_val ""
              if {[string match "PROT0" $multiple_freq_prot_type]} {  
                  set prot_val "PROT0"
              } elseif {[string match "PROT1" $multiple_freq_prot_type]} {  
                  set prot_val "PROT1"
              } elseif {[string match "PROT2" $multiple_freq_prot_type]} {  
                  set prot_val "PROT2"
              } elseif {[string match "PROT3" $multiple_freq_prot_type]} {  
                  set prot_val "PROT3"
              } elseif {[string match "PROT4" $multiple_freq_prot_type]} {  
                  set prot_val "PROT40"
              } elseif {[string match "PROT5" $multiple_freq_prot_type]} {  
                  set prot_val "PROT5"
              } elseif {[string match "PROT6" $multiple_freq_prot_type]} {  
                  set prot_val "PROT6"
              } else {  
                  set prot_val "PROT7"
              } 
              set lkey [dict get $LANE_SEL_DICT $prot_val]
               set lkeya [split $lkey " "]
               set lkeya1 [lindex $lkeya 0]
               set lkeyf "$quadCell\/$lkeya1\_GT_IP_INTERFACE"
               set pCellName [find_connected_core $lkeyf]
              lappend list_AK0 $pCellName
               
           } else {
             set freq_val_with_prot_src [string map {"\_unique6" ""} [string map {"\_unique5" ""} [string map {"\_unique4" ""} [string map {"\_unique3" ""} [string map {"\_unique2" ""} [string map {"\_unique1" ""} [string map {"\_MHz" ""}  [string map {"refclk_" ""} $temp ]]]]]]]]
              set freq_val_with_prot_src_space [string map {"\_" " "}  $freq_val_with_prot_src ]
              set new_list [list ]
              set new_list $freq_val_with_prot_src_space
              set freq_val_with_prot_src_space [lsearch -inline -all -not -exact $new_list $freq_val]
              set prot_src_dict [dict create]
              set prot_src_dict $freq_val_with_prot_src_space
              set prot_src_info ""
              set snumk [expr $snumk+1]
              set list_AK0 [list $snumk]
              set ref_name $quadCell\/GT_REFCLK$n    
              set ref_clk_src [find_connected_core $ref_name]
              lappend list_AK0 $ref_name              
              set SRC ""
              set prot_src_info ""
               foreach PROT { PROT0 PROT1 PROT2 PROT3 PROT4 PROT5 PROT6 PROT7 } {
               if { [dict exists $prot_src_dict $PROT] } {
                  set SRC [dict get $prot_src_dict $PROT]
                  set prot_src_info [concat "$prot_src_info $PROT,"]
               }
               }
               set prot_src_info1 [string range $prot_src_info 0 end-1]
               set prot_src_sp [split $prot_src_info1 " "]
               lappend list_AK0 $freq_val
               set pCellName ""
               set pCellName1 ""               
               set num_parIP 0
               foreach ikk $prot_src_sp {
               set num_parIP [expr $num_parIP+1]

                ## Check here, update PROT vs RX/TX interface level logic
               set prot_src_info2 $ikk
               set prot_src_sp1 [split $prot_src_info2 ","]
               set prot_src_info [lindex $prot_src_sp1 0]
               set lkey [dict get $LANE_SEL_DICT $prot_src_info]
               set lkeya [split $lkey " "]
               set lkeya [lsort -unique $lkeya]

               set lkeya1 [lindex $lkeya 0]
               set lkeyf "$quadCell\/$lkeya1\_GT_IP_INTERFACE"
               set pCellName [find_connected_core $lkeyf]
               lappend pCellName1 $pCellName
               set pCellName1 [lsort -unique $pCellName1]
               if {$num_parIP > 1} {
                 set pCellName [join $pCellName1 ","]
               } else {
                 set pCellName $pCellName1
               }   

               }           
               lappend list_AK0 $pCellName


           }
          lappend list_AK0 $ref_clk_src
          $tbl1 addrow $list_AK0  
   
         }
        }

        puts $outfilek [$tbl1 print]
        puts $outfilek "  "
        puts $outfilek "  "
        puts $outfilek "================================================== Notes and Example =================================================="
        puts $outfilek "  "
        puts $outfilek "Note:     If Quad reference clock frequencies are same, user could optimize the reference clock inputs by shorting them."
        puts $outfilek "          If the REFCLK sources are same for multiple ref clocks in the table, that indicates those ref clocks are already shorted."
        puts $outfilek "          Example gtye5_refclk_summary.txt given below "
        puts $outfilek "          +-------+-----------------------------+------------+-------------+------------------+"
        puts $outfilek "          | S.No. |       GTYE5_REFCLOCK Name   | Freq       | ParentIP    |   REFCLK Source  |"
        puts $outfilek "          +-------+-----------------------------+------------+-------------+------------------+"
        puts $outfilek "          | 1     | /<gt_quad_base_i>/GTREFCLK0 | 156.250000 | <ParentIPx> | <REFCLK Sourcex> |"
        puts $outfilek "          | 2     | /<gt_quad_base_j>/GTREFCLK1 | 156.250000 | <ParentIPy> | <REFCLK Sourcey> |"
        puts $outfilek "          | 3     | /<gt_quad_base_k>/GTREFCLK2 | 156.250000 | <ParentIPz> | <REFCLK Sourcez> |"
        puts $outfilek "          | 4     | /<gt_quad_base_l>/GTREFCLK0 | 250.000000 | <ParentIPa> | <REFCLK Sourcea> |"
        puts $outfilek "          | 5     | /<gt_quad_base_m>/GTREFCLK1 | mutiple    | <ParentIPb> | <REFCLK Sourceb> |"
        puts $outfilek "          | 6     | /<gt_quad_base_n>/GTREFCLK2 | mutiple    | <ParentIPc> | <REFCLK Sourcec> |"
        puts $outfilek "          +-------+-----------------------------+------------+-------------+------------------+"
        puts $outfilek "          In this table, it is possible to short the first three GTREFCLKs that are of same frequency values."
        puts $outfilek " "
        puts $outfilek "          Please follow below steps to short the Quad reference clock sources. "
        puts $outfilek "          1) Remove the Utility Buffer instantiation and associated external port connected to <gt_quad_base_j>_GTREFCLK1, <gt_quad_base_k>_GTREFCLK2"
        puts $outfilek "          2) Short the required gt_quad_base reference clocks (<gt_quad_base_i>_GTREFCLK0,<gt_quad_base_j>_GTREFCLK1,<gt_quad_base_k>_GTREFCLK2) at the Quad instance level."
        puts $outfilek ""
        puts $outfilek "Imp Note: While optimizing please ensure Quads are placed adjacently and follow below rules(please refer AM002-Chapter2 Section:Reference clock selection and distribution)."
        puts $outfilek " "
        puts $outfilek "          For Versal devices, sourcing of the reference clock is limited to two Quads above and below, when the channel"
        puts $outfilek "          is operating below 16.375 Gb/s. For line rates higher than 16.375 Gb/s, no reference clock sharing is allowed."
        puts $outfilek " "
        puts $outfilek " "
        puts $outfilek " =========================== Command to generate GTYE5_REFCLOCK Summary in gt_quad_base IP based designs ======================="
        puts $outfilek " "
        puts $outfilek "                                              xilinx::designutils::report_gtye5_refclk_summary"

        close $outfilek
    set done [add_files -norecurse $file_name]
    set done [import_files -force $file_name]
    set done [file delete -force $pathk\/GTREFCLK_SUMMARY -quiet] 
    puts " \n\n**************************************************************************" 
    puts "INFO: \[GT_UTILS 1-1\] GTYE5_refclk_summary text file written out $file_name"
    puts "**************************************************************************\n" 
}
return ""

}

#------------------------------------------------------------------------
# lshift
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Stack function
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}


proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::find_connected_pin { connected_to } {
  # Summary: 
  # Gives the connected pin information

  # Argument Usage: 

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: Xilinxtclstore, projutils

    if {[string length $connected_to] == 0} {
    return ""
  }

  # Find pin or interface pin
  set pin [get_bd_intf_pins -quiet $connected_to]
  if {[string length $pin] == 0} {
    set pin [get_bd_pins -quiet $connected_to]
  }
  if {[string length $pin] == 0} {
    return ""
  }

  # Find connected pin and its core
  set pin [find_bd_obj -quiet -legacy_mode -relation connected_to $pin]
  return $pin
 }


proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::find_connected_core { connected_to } {
  # Summary: 
  # Gives the connected core information

  # Argument Usage: 

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: Xilinxtclstore, projutils
  # Find connected pin and its core
  set pin [find_connected_pin ${connected_to}]
  if {[string length $pin] == 0} {
    return ""
  }
  set obj [get_bd_cells -quiet -of_objects $pin]

  # Traverse up the hierarchy, checking for appcore
  set cell [get_parent $obj]
  while {[string length $cell] > 0} {
    set vlnv [get_property -quiet VLNV $cell]
    if {[string length $vlnv] > 0} {
      set obj $cell
    }
    set cell [get_parent $cell]
  }

  return $obj
}


proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::get_parent {obj} {
  # Summary: 
  # Gives the parent information

  # Argument Usage: 

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: Xilinxtclstore, projutils

  set c [join [lrange [split $obj /] 0 end-1] /]
  if { $c == "" || $c == "/" } {
    return ""
  }
  return [get_bd_cells -quiet $c]
}

proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::not_empty_int {obj} {
  # Summary: 
  # Gives the information of empty or non empty

  # Argument Usage: 

  # Return Value:
 
  if { $obj != "" } {
    return 1
  } else {
    return 0
  }
}

proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::evaluate_bd_properties { tx0Handle tx1Handle tx2Handle tx3Handle rx0Handle rx1Handle rx2Handle rx3Handle } {
  # Summary: 
  # Evaluates block design properties and create a dict

  # Argument Usage: 

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: Xilinxtclstore, projutils


       set settings_string [dict create] 


        set CHNL_ORDER [dict create]
        foreach txIdx { 0 1 2 3 } {
            set var "tx${txIdx}Handle"
            set txHandle [subst $$var]
            if {[string length $txHandle] > 0} {
                incr no_of_active_txlanes
                set TX${txIdx}_PARENTPIN         [find_connected_pin $txHandle]
                set var2 "TX${txIdx}_PARENTPIN"
                set ParentPin [subst $$var2]
                if {$ParentPin == ""} {
                set TX${txIdx}_PARENT_ID         "undef" 
                } else {
                set TX${txIdx}_PARENT_ID         [get_property CONFIG.PARENT_ID $txHandle] 
                }
                set TX${txIdx}_CHNL_NUMBER       [get_property CONFIG.CHNL_NUMBER $txHandle] 
                set TX${txIdx}_MASTERCLK_SRC     [get_property CONFIG.MASTERCLK_SRC $txHandle] 
                #set TX${txIdx}_ADDN_FILE     [get_property CONFIG.ADDITIONAL_CONFIG_FILE $txHandle] 
                set TX${txIdx}_GT_DIRECTION  [get_property CONFIG.GT_DIRECTION $txHandle] 
                set TX${txIdx}_GT_SETTINGS       [get_property CONFIG.TX_SETTINGS $txHandle]  
                set var "TX${txIdx}_PARENT_ID"
                set PID [subst $$var] 
                
                set var3 "TX${txIdx}_CHNL_NUMBER"
                set ParentChnlIdx [subst $$var3]
                if { [get_property CONFIG.PARENT_ID $txHandle] ne "undef" && [get_property CONFIG.CHNL_NUMBER $txHandle] ne "undef" } {
                  lappend CHNL_ORDER $txHandle $PID.$ParentPin.$ParentChnlIdx
                }
            }
        }
       
        foreach rxIdx { 0 1 2 3 } {
            set var "rx${rxIdx}Handle"
            set rxHandle [subst $$var]
            if {[string length $rxHandle] > 0} {
                set RX${rxIdx}_PARENTPIN         [find_connected_pin $rxHandle]
                set var2 "RX${rxIdx}_PARENTPIN"
                set ParentPin [subst $$var2]
                if {$ParentPin == ""} {
                set RX${rxIdx}_PARENT_ID         "undef" 
                } else {
                set RX${rxIdx}_PARENT_ID         [get_property CONFIG.PARENT_ID $rxHandle] 
                }
                set RX${rxIdx}_CHNL_NUMBER       [get_property CONFIG.CHNL_NUMBER $rxHandle] 
                set RX${rxIdx}_MASTERCLK_SRC     [get_property CONFIG.MASTERCLK_SRC $rxHandle] 
                #set RX${rxIdx}_ADDN_FILE     [get_property CONFIG.ADDITIONAL_CONFIG_FILE $rxHandle] 
                set RX${rxIdx}_GT_DIRECTION  [get_property CONFIG.GT_DIRECTION $rxHandle] 
                set RX${rxIdx}_GT_SETTINGS       [get_property CONFIG.RX_SETTINGS $rxHandle]
                set var "RX${rxIdx}_PARENT_ID"
                set PID [subst $$var] 
                
                set var3 "RX${rxIdx}_CHNL_NUMBER"
                set ParentChnlIdx [subst $$var3]
                if { [get_property CONFIG.PARENT_ID $rxHandle] ne "undef" && [get_property CONFIG.CHNL_NUMBER $rxHandle] ne "undef" } {
                  lappend CHNL_ORDER $rxHandle $PID.$ParentPin.$ParentChnlIdx
                }
            }
        }
        ###set CHANNEL_ORDERING ${CHNL_ORDER} $cell
        set settings_string [dict merge $settings_string [dict create CHANNEL_ORDERING ${CHNL_ORDER}]] 
    ##################################### setting initial values to default  ############################################################################
       foreach int { TX0 TX1 TX2 TX3 RX0 RX1 RX2 RX3 } {
         ##set ${int}_LANE_SEL "unconnected" $cell 
        set settings_string [dict merge $settings_string [dict create ${int}_LANE_SEL "unconnected"]] 
       }  
    ###########################################################################################################################################################
    ######################################## Creating a single DICT with parent IDs as keys and lanes as values  ##############################################
        set IP_DICT [dict create] 
         if {[string equal -nocase $RX0_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $RX0_PARENT_ID RX0
         }
         if {[string equal -nocase $RX1_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $RX1_PARENT_ID RX1
         }
         if {[string equal -nocase $RX2_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $RX2_PARENT_ID RX2
         }
         if {[string equal -nocase $RX3_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $RX3_PARENT_ID RX3
         }
         if {[string equal -nocase $TX0_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $TX0_PARENT_ID TX0
         }
         if {[string equal -nocase $TX1_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $TX1_PARENT_ID TX1
         }
         if {[string equal -nocase $TX2_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $TX2_PARENT_ID TX2
         }
         if {[string equal -nocase $TX3_PARENT_ID "undef"] == 0}  { 
            dict lappend IP_DICT $TX3_PARENT_ID TX3
         }
    ###########################################################################################################################################################
    ###################################### Editing the dict to replace keys from parent_ids to PROT* ##########################################################
       set NO_OF_IP [dict size $IP_DICT]    
       set ALL_KEYS [dict keys $IP_DICT]
       set IP_DICT2 [dict create] 
       set INITIAL_VALUE " "
       for {set i 0} {$i < $NO_OF_IP} {incr i} {
         set K [lindex $ALL_KEYS $i]
         dict append IP_DICT2 PROT$i [dict get $IP_DICT $K]
         ##set PROT${i}_ENABLE "true" $cell 
         set settings_string [dict merge  $settings_string [dict create PROT${i}_ENABLE "true"] ]
         set settings_string [dict merge $settings_string [dict create PROT${i}_TX_MASTERCLK_SRC "None"]] 
         set settings_string [dict merge $settings_string [dict create PROT${i}_RX_MASTERCLK_SRC "None"]] 
         foreach LR_num { 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15} {
           set settings_string [dict merge $settings_string [dict create PROT${i}_LR${LR_num}_SETTINGS $INITIAL_VALUE] ]
         }
       }  
    ###########################################################################################################################################################
    ##################################################################################################################################
    ###    1. Take each PROT , take the first TX(RX) and/or RX(TX) associated with and obtain the various parameters.     ############
    ###    2. Count the number of TX, rx associated with each PROT to determine if its SIMPLEX/DUPLEX.                    ############
    ###    3. ASSIGN all the variable associated with each PROT                                                           ############
        foreach int { PROT0 PROT1 PROT2 PROT3 PROT4 PROT5 PROT6 PROT7 } {
          set LANES [dict values [dict filter $IP_DICT2 key $int]]
          set NO_OF_TX 0
          set NO_OF_RX 0
          #seems to be a 2 level dict, needing 2 for loops, not sure exactly why.
          foreach i $LANES {
            foreach m $i {
              set settings_string [dict merge $settings_string [dict create ${m}_LANE_SEL $int] ]
              if {[string match "*TX*" $m] } {
               set var_name0 "${m}_GT_SETTINGS"
               set TX_Settings [subst $$var_name0] 
               if {$NO_OF_TX == 0} {
                 foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
                   if {[dict exists $TX_Settings ${LR}_SETTINGS]}  { 
                     set TX_${LR}_INT_SETTINGS [dict get $TX_Settings ${LR}_SETTINGS]
                   }
                 }
               } else {
               }
               set masterclk_src "${m}_MASTERCLK_SRC"
               if { [subst $$masterclk_src] == 1 } {
                 set settings_string [dict merge $settings_string [dict create ${int}_TX_MASTERCLK_SRC $m]] 
               }
               #set additional_file "${m}_ADDN_FILE"
               #if { [subst $$additional_file] != "" } {
               #if { [subst $$additional_file] != "no_addn_file_loaded" } {
               #  set settings_string [dict merge $settings_string [dict create ${int}_ADD_CONFIG_EN "false" ]] 
               #  set settings_string [dict merge $settings_string [dict create ${int}_ADD_CONFIG_FILE [subst $$additional_file]]] 
               #}
               #}
               incr NO_OF_TX
              } elseif {[string match "*RX*" $m] } {
               set var_name0 "${m}_GT_SETTINGS"
               set RX_Settings [subst $$var_name0] 
               if {$NO_OF_RX == 0} {
                 if {[dict exists $RX_Settings TANDEM_SETTINGS]}  { 
                   set settings_string [dict merge $settings_string [dict create TANDEM_MODE "true"] ]
                 }
                 foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
                   if {[dict exists $RX_Settings ${LR}_SETTINGS]}  { 
                     set RX_${LR}_INT_SETTINGS [dict get $RX_Settings ${LR}_SETTINGS]
                   }
                 }
                } else {
               }
               set masterclk_src "${m}_MASTERCLK_SRC"
               if { [subst $$masterclk_src] == 1 } {
                 set settings_string [dict merge $settings_string [dict create ${int}_RX_MASTERCLK_SRC $m] ]
               }
               #set additional_file "${m}_ADDN_FILE"
               #if { [subst $$additional_file] != "" } {
               #if { [subst $$additional_file] != "no_addn_file_loaded" } {
               #  set settings_string [dict merge $settings_string [dict create ${int}_ADD_CONFIG_EN "false" ]] 
               #  set settings_string [dict merge $settings_string [dict create ${int}_ADD_CONFIG_FILE [subst $$additional_file]]] 
               #}
               #}
               incr NO_OF_RX
              }
            }
          }
          if { ($NO_OF_RX > 0) && ($NO_OF_TX == 0) } {
            set settings_string [dict merge $settings_string [dict create ${int}_GT_DIRECTION "SIMPLEX_RX"] ]
            set settings_string [dict merge $settings_string [dict create ${int}_NO_OF_RX_LANES $NO_OF_RX]] 
            set INT_VAR "GT_DIRECTION SIMPLEX_RX"
            foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
              if { [dict exists $RX_Settings ${LR}_SETTINGS] }  { 
                 set LR_SET_RX "RX_${LR}_INT_SETTINGS"
                 set LR_SET_TEMP_RX [subst $$LR_SET_RX]
                 set TEMP_SETTINGS_RX [append INT_VAR " " $LR_SET_TEMP_RX] 
                 set settings_string [dict merge $settings_string [dict create ${int}_${LR}_SETTINGS [get_GT_settings $TEMP_SETTINGS_RX]] ]
              }
            }
          } elseif { ($NO_OF_RX == 0) && ($NO_OF_TX > 0) } {
            set settings_string [dict merge $settings_string [dict create ${int}_GT_DIRECTION "SIMPLEX_TX"] ]
            set settings_string [dict merge $settings_string [dict create ${int}_NO_OF_TX_LANES $NO_OF_TX] ]
            set INT_VAR "GT_DIRECTION SIMPLEX_TX"
            foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
              if { [dict exists $TX_Settings ${LR}_SETTINGS] }  { 
                 set LR_SET_TX "TX_${LR}_INT_SETTINGS"
                 set LR_SET_TEMP_TX [subst $$LR_SET_TX]
                 set TEMP_SETTINGS_TX [append INT_VAR " " $LR_SET_TEMP_TX]
                 set settings_string [dict merge $settings_string [dict create ${int}_${LR}_SETTINGS [get_GT_settings $TEMP_SETTINGS_TX]] ]
              }
            }
          } elseif { ($NO_OF_RX > 0) && ($NO_OF_TX > 0) && ($NO_OF_TX == $NO_OF_RX) } {
            set settings_string [dict merge $settings_string [dict create ${int}_GT_DIRECTION "DUPLEX"] ]
            set settings_string [dict merge $settings_string [dict create ${int}_NO_OF_LANES $NO_OF_TX] ]
            set INT_VAR "GT_DIRECTION DUPLEX"
            foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
              if { [dict exists $RX_Settings ${LR}_SETTINGS] && [dict exists $TX_Settings ${LR}_SETTINGS]}  { 
                 set LR_SET_RX "RX_${LR}_INT_SETTINGS"
                 set LR_SET_TX "TX_${LR}_INT_SETTINGS"
                 set LR_SET_TEMP_RX [subst $$LR_SET_RX]
                 set LR_SET_TEMP_TX [subst $$LR_SET_TX]
                 set TEMP_SETTINGS_DUPLEX [append INT_VAR " " $LR_SET_TEMP_TX " " $LR_SET_TEMP_RX] 
                 set settings_string [dict merge $settings_string [dict create ${int}_${LR}_SETTINGS [get_GT_settings $TEMP_SETTINGS_DUPLEX]]] 
              }
            }
          } elseif { ($NO_OF_RX > 0) && ($NO_OF_TX > 0) && ($NO_OF_TX != $NO_OF_RX) } {
            set settings_string [dict merge $settings_string [dict create ${int}_GT_DIRECTION "ASYMMETRIC"]] 
            set settings_string [dict merge $settings_string [dict create ${int}_NO_OF_TX_LANES $NO_OF_TX]] 
            set settings_string [dict merge $settings_string [dict create ${int}_NO_OF_RX_LANES $NO_OF_RX]] 
            set INT_VAR "GT_DIRECTION ASYMMETRIC"
            foreach LR { LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 LR9 LR10 LR11 LR12 LR13 LR14 LR15 } {
              if { [dict exists $RX_Settings ${LR}_SETTINGS] && [dict exists $TX_Settings ${LR}_SETTINGS]}  { 
                 set LR_SET_RX "RX_${LR}_INT_SETTINGS"
                 set LR_SET_TX "TX_${LR}_INT_SETTINGS"
                 set LR_SET_TEMP_RX [subst $$LR_SET_RX]
                 set LR_SET_TEMP_TX [subst $$LR_SET_TX]
                 set TEMP_SETTINGS_DUPLEX [append INT_VAR " " $LR_SET_TEMP_TX " " $LR_SET_TEMP_RX] 
                 ##set ${int}_${LR}_SETTINGS [get_GT_settings $TEMP_SETTINGS_DUPLEX] $cell
                 set settings_string [dict merge $settings_string [dict create ${int}_${LR}_SETTINGS [get_GT_settings $TEMP_SETTINGS_DUPLEX]]] 
              }
            }
          }
        }


  return $settings_string
}

proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::map_int {lambda larg {cull_empty 0}} {
  # Summary: 
  # Maps latest vlnv 

  # Argument Usage: 

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: Xilinxtclstore, projutils

    
  set result {}
  foreach i $larg {
    set tmp [apply $lambda $i]
    if {$cull_empty} {
       if {[not_empty_int $tmp]} {
          lappend result $tmp
       }
    } else { 
      lappend result $tmp
    }
  }
  return $result
}

  proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::get_latest_vlnv {} {

  # Summary: 
  # Gives the latest vlnv of quad base IP

  # Argument Usage: 

  # Return Value:
  # returns latest vlnv of quad base IP

  # Categories: Xilinxtclstore, projutils


    set vlnv [get_ipdefs -quiet -filter {VLNV=~xilinx.com:ip:gt_quad_base:*}]
    set latestVlnvs [list ]
    if {[llength $vlnv] > 1} {
      foreach ipv $vlnv {
        if { [ string match *ip:gt_quad_base* $ipv] } {
          lappend latestVlnvs $ipv
        }
      }
    }
    
    set finalVlnv ""
    
    if {[llength $latestVlnvs] eq 0} {
      set finalVlnv [lindex $vlnv 0]
    } elseif {[llength $latestVlnvs] > 1} {
      set version_list [map_int {x {return [get_property VERSION $x]}} $latestVlnvs]
      set sorted_version [lsort -real -decreasing ${version_list}]
      set finalVlnv [get_ipdefs -all xilinx.com:ip:gt_quad_base:[lindex ${sorted_version} 0]]
    } elseif {[llength $latestVlnvs] eq 1} {
      set finalVlnv [lindex $latestVlnvs 0]
    }
    return $finalVlnv
  }

  proc ::tclapp::xilinx::designutils::report_gtye5_refclk_summary::EvalSubstituting {parameters procedure {numlevels 1}} {
  # Summary: 
  # Used internally to get the quad base instances 

  # Argument Usage:
  # Return Value:

  # quad base instance details
  # Categories: Xilinxtclstore, projutils

      set paramlist {}
      if {[string index $numlevels 0]!="#"} {
         set numlevels [expr $numlevels+1]
      }
      foreach parameter $parameters {
         upvar 1 $parameter $parameter\_value
         tcl::lappend paramlist \$$parameter [set $parameter\_value]
      }
      uplevel $numlevels [string map $paramlist $procedure]
  }
#}
