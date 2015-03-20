
########################################################################################
## 01/30/2015 - Updated for 2015.1 
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store 
## 02/03/2014 - Updated the namespace and definition of the command line arguments 
##              for the Tcl App Store
## 09/18/2013 - Changes for 2013.3
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/10/2013 - Minor updates to output formating
##            - Major updates to output formating
##              (James Lucero)
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 09/06/2013 - Initial release based on interconnect_info.tcl version 09/05/2013
##              (James Lucero)
########################################################################################

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export check_bd_axi_interface

}

proc ::tclapp::xilinx::ultrafast::check_bd_axi_interface { args } {
  # Summary: Report AXI Interconnect Internal Blocks for Every AXI Master and AXI Slave in an AXI Interconnect instance

  # Argument Usage:
  # [<arg>]: Block name(s) with AXI interface
  # [-block <arg>]: Block name with AXI interface
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::check_bd_axi_interface::check_bd_axi_interface $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::check_bd_axi_interface {
  variable version {01/30/2015}
} ]

#JEL 2013.2
#Official release 9/5/13
#Report bugs to jamesl@xilinx.com

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#


proc ::tclapp::xilinx::ultrafast::check_bd_axi_interface::check_bd_axi_interface { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set blockNames [list]
  set filename {}
  set mode {w}
  set returnString 0
  set help 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
      -block -
      {^-(b(l(o(ck?)?)?)?)?$} {
           # Flatten the list to cover the case $name is a Tcl list of elements
           set blockNames [ [namespace parent]::lflatten [concat $blockNames [[namespace parent]::lshift args] ] ]
      }
      -file -
      {^-f(i(le?)?)?$} {
           set filename [[namespace parent]::lshift args]
           if {$filename == {}} {
             puts " -E- no filename specified."
             incr error
           }
      }
      -append -
      {^-a(p(p(e(nd?)?)?)?)?$} {
           set mode {a}
      }
      -return_string -
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} -
      -help -
      {^-h(e(lp?)?)?$} {
           set help 1
      }
      ^--version$ {
           variable version
           return $version
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              # Flatten the list to cover the case $name is a Tcl list of elements
#               set blockNames [::tclapp::xilinx::ultrafast::lflatten [concat $blockNames $name]]
              set blockNames [[namespace parent]::lflatten [concat $blockNames $name]]
#               puts " -E- option '$name' is not a valid option."
#               incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: check_bd_axi_interface
              <arg>[<arg>..<arg>]    - Block name(s) with AXI interface
              [-block <arg>]         - Block name with AXI interface
              [-file]                - Report file name
              [-append]              - Append to file
              [-return_string]       - Return report as string
              [-usage|-u]            - This help message

  Description: Report AXI Interconnect Internal Blocks for Every AXI Master
               and AXI Slave in an AXI Interconnect instance.

     This command must be run on an opened block design.

  Example:
     check_bd_axi_interface -block axi_interconnect_1 -file myreport.rpt
     check_bd_axi_interface -block axi_interconnect_1 -block axi_interconnect_2 -block axi_interconnect_3
} ]
    # HELP -->
    return {}
  }

  if {$blockNames == {}} {
    puts " -E- no AXI Interconnect name was provided."
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set output [list]
  foreach block $blockNames {
    lappend output {}
    lappend output {####################################}
    lappend output [format {## Block: %s} $block ]
    lappend output {####################################}
    lappend output {}
#     set output [concat $output [InterInfo $block]]
    foreach line [InterInfo $block] {
      # Indent the lines
      lappend output [format {  %s} $line]
    }
  }

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {check_bd_axi_interface}]
    puts $FH [join $output \n]
    close $FH
    puts "\n Report file [file normalize $filename] has been generated\n"
  } else {
    puts [join $output \n]
  }

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }

  return 0
}


proc ::tclapp::xilinx::ultrafast::check_bd_axi_interface::InterInfo { InterconnectInstanceName } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  lappend output [list]

  #Common Variables
  set BACKSLASH "/"
  set INTERCONNECT_NAME_VAR [concat ${BACKSLASH}${InterconnectInstanceName}]

  set AXI_NAME "_AXI"
  set HAS_REG "_HAS_REGSLICE"
  set HAS_FIFO "_HAS_DATA_FIFO"
  set MON_MODE "Monitor"
  set EMPTY_VALUE ""
  set S_AXI_NAME "/S_AXI"
  set M_AXI_NAME "/M_AXI"
  set VAL_SUCCESS ""

  set WRITE_ACCEPT "_WRITE_ACCEPTANCE"
  set READ_ACCEPT "_READ_ACCEPTANCE"

  set WRITE_ISSUE "_WRITE_ISSUING"
  set READ_ISSUE "_READ_ISSUING"

  #Check to See if Interconnect Instance exists

  set INTER_EXIST [get_bd_cells $INTERCONNECT_NAME_VAR -quiet]

  set INTER_EXIST_VALUE [string match $INTER_EXIST $EMPTY_VALUE]

  if {$INTER_EXIST_VALUE == 0} {
  } else {
    lappend output "AXI Instance name is not found! Please Verify And Rerun Script!"
    return $output
  }

  lappend output "Validating BD design... This will take a few minutes"

  #Check to see if design has been validated
  set VALIDATE_DESIGN [validate_bd_design]

  set VALIDATE_REPORT [string match $VALIDATE_DESIGN $VAL_SUCCESS]

  if {$VALIDATE_REPORT == 1} {
    lappend output "Validation Passed!"
  } else {
    lappend output "BD design failed validation! Please Fix The Design and Rerun The Script!"
    return $output
  }

  lappend output " "

  #Settings for main Interconnect

  set INTERCON_SETTINGS $INTERCONNECT_NAME_VAR

  set XBAR_EXIST [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar -quiet]

  if {$XBAR_EXIST != ""} {
  set INTER_DATAWIDTH [get_property {CONFIG.DATA_WIDTH} [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar]]
  lappend INTERCON_SETTINGS $INTER_DATAWIDTH

  set INTER_CLK_DMN [get_property CONFIG.CLK_DOMAIN [get_bd_pins ${INTERCONNECT_NAME_VAR}/xbar/aclk]]
  lappend INTERCON_SETTINGS $INTER_CLK_DMN

  set INTER_FREQ [get_property CONFIG.FREQ_HZ [get_bd_pins ${INTERCONNECT_NAME_VAR}/xbar/aclk]]
  lappend INTERCON_SETTINGS $INTER_FREQ

  #Set number of Slave and report
  set NUM_SI [get_property {CONFIG.NUM_SI} [get_bd_cells ${INTERCONNECT_NAME_VAR}]]
  set NUM_MI [get_property {CONFIG.NUM_MI} [get_bd_cells ${INTERCONNECT_NAME_VAR}]]

  lappend INTERCON_SETTINGS $NUM_SI
  lappend INTERCON_SETTINGS $NUM_MI

  set INTER_STRAT [get_property CONFIG.STRATEGY [get_bd_cells ${INTERCONNECT_NAME_VAR}]]

  if {$INTER_STRAT == 0} {
     lappend INTERCON_SETTINGS "Custom"
  } elseif {$INTER_STRAT == 1} {
     lappend INTERCON_SETTINGS "Area Optimized (Shared Mode)"
  } elseif {$INTER_STRAT == 2} {
     lappend INTERCON_SETTINGS "High Performance(Crossbar Mode)"
  } else {
     lappend INTERCON_SETTINGS "Not Known"
  }

  lappend output " "

  set tbl [[namespace parent]::Table::Create]
  $tbl title "AXI Interconnect"
  $tbl header [list "name" "DW" "CLK DOMAIN" "FREQ" "AXI MASTERS" "AXI SLAVES" "STRATEGY"]
  $tbl addrow $INTERCON_SETTINGS
  set output [concat $output [split [$tbl print] \n]  ]
  catch {$tbl destroy}

  unset INTERCON_SETTINGS
  
  } else {
    set NUM_SI 1
    set NUM_MI 1
    puts "$INTERCONNECT_NAME_VAR 1 Master x 1 Slave Mode"  
  }

  lappend output " "

  #Show Interconnect settings for masters and master settings
  for {set MASTERS 0} {$MASTERS < $NUM_SI} {incr MASTERS 1} {

    #Check to see if master is less then 9, since a 0 needs to be before
    if {$MASTERS <= 9} {
      set MASTER_NUMBER "/S0${MASTERS}"
      set MASTER_NUMBER_CONFIG "CONFIG.S0${MASTERS}"
      set MASTER_PC_NUMBER "/s0${MASTERS}_couplers/auto_pc"
      set MASTER_SAMP_NUMBER "/s0${MASTERS}_couplers/auto_*s*"
      set MASTER_CC_NUMBER "/s0${MASTERS}_couplers/auto_cc"
      set MASTER_SAMP_NUMBER_RS "/s0${MASTERS}_couplers/auto_rs"
    } else {
      set MASTER_NUMBER "/S${MASTERS}"
      set MASTER_NUMBER_CONFIG "CONFIG.S${MASTERS}"
      set MASTER_PC_NUMBER "/s${MASTERS}_couplers/auto_pc"
      set MASTER_SAMP_NUMBER "/s${MASTERS}_couplers/auto_*s*"
      set MASTER_CC_NUMBER "/s${MASTERS}_couplers/auto_cc"
      set MASTER_SAMP_NUMBER_RS "/s${MASTERS}_couplers/auto_rs"
    }

    #Setup Config variables
    set CONFIG_REG_NAME [concat "$MASTER_NUMBER_CONFIG$HAS_REG"]
    set CONFIG_FIFO_NAME [concat "$MASTER_NUMBER_CONFIG$HAS_FIFO"]
    set CONFIG_S_READ_ACCEPT [concat "$MASTER_NUMBER_CONFIG$READ_ACCEPT"]
    set CONFIG_S_WRITE_ACCEPT [concat "$MASTER_NUMBER_CONFIG$WRITE_ACCEPT"]

    #Setup Master Instance names and see if monitor is being used
    set MASTER_NAME [concat ${INTERCONNECT_NAME_VAR}${MASTER_NUMBER}$AXI_NAME]
    #lappend output "$MASTER_NAME"

    set MASTER_INTERFACE_NET_NAME [get_bd_intf_net -of_objects [get_bd_intf_pin $MASTER_NAME]]
    #lappend output "Master Interface Name ${MASTER_INTERFACE_NET_NAME}"

    set MASTER_INTERFACE_PIN_NAME [get_bd_intf_pins -of_objects [get_bd_intf_net $MASTER_INTERFACE_NET_NAME]]
    #lappend output "Master Interface Name ${MASTER_INTERFACE_PIN_NAME}"

    foreach ARRAY_VALUE $MASTER_INTERFACE_PIN_NAME {

      set STRING_COMPARE [string match $MASTER_NAME $ARRAY_VALUE]
      #lappend output "$STRING_COMPARE"

      #Check and make sure master is not a monitor
      set MASTER_MODE [get_property MODE [get_bd_intf_pins $ARRAY_VALUE]]
      set MODE_STRING_COMPARE [string match $MASTER_MODE $MON_MODE]

      if {$STRING_COMPARE == 0} {
        if {$MODE_STRING_COMPARE == 0} {
          set MASTER_INTERFACE_NAME $ARRAY_VALUE
        }
      }

    }

    #Set vars for FIFO and issuance
    set REG_VALUE [get_property $CONFIG_REG_NAME [get_bd_cells ${INTERCONNECT_NAME_VAR}]]
    set FIFO_VALUE [get_property $CONFIG_FIFO_NAME [get_bd_cells ${INTERCONNECT_NAME_VAR}]]
    
  if {$XBAR_EXIST != ""} {
    set READ_ISSUE_VALUE [get_property $CONFIG_S_READ_ACCEPT [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar]]
    set WRITE_ISSUE_VALUE [get_property $CONFIG_S_WRITE_ACCEPT [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar]]
    } else {
      set READ_ISSUE_VALUE "N/A"
      set WRITE_ISSUE_VALUE "N/A"      
    }
    


    
    #Check to see if sampler up or down is used, also check clock conversion as well in module or CC

    set CHECK_SAMP_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$MASTER_SAMP_NUMBER"]
    set SAMP_EXIST [get_bd_cells $CHECK_SAMP_CELL_NAME -quiet]
    set SAMP_EXIST_VALUE [string match $SAMP_EXIST $EMPTY_VALUE]


    if {$SAMP_EXIST_VALUE == 0} {
      set CELL_NAMES [get_bd_cells $CHECK_SAMP_CELL_NAME]
        foreach CELL $CELL_NAMES {
          #Since RS will be confused for samplers, add extra case
          set CHECK_RS_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$MASTER_SAMP_NUMBER_RS"]
          set RS_EXIST_VALUE [string match $CELL $CHECK_RS_CELL_NAME]

          if {$RS_EXIST_VALUE == 1} {
            #Don't Do Anything yet
          } else {
            set SAMP_USED "YES"
            set SAMP_SI_WIDTH [get_property {CONFIG.SI_DATA_WIDTH} [get_bd_cells $CELL]]
            set SAMP_MI_WIDTH [get_property {CONFIG.MI_DATA_WIDTH} [get_bd_cells $CELL]]

            if {$FIFO_VALUE > 0} {

              #See if both clocks connected, if so CC is used
              set M_CLK [get_bd_pin $CELL/m_axi_aclk -quiet]
              set M_CLK_EXIST_VALUE [string match $M_CLK $EMPTY_VALUE]

              set S_CLK [get_bd_pin $CELL/s_axi_aclk -quiet]
              set S_CLK_EXIST_VALUE [string match $S_CLK $EMPTY_VALUE]

              #Compare Interconnect Frequency to Slave frequency, if not equal CC is used
              if {[string equal $M_CLK_EXIST_VALUE $S_CLK_EXIST_VALUE]} {
                set CC_USED "YES"
                set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CELL]]
                set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CELL]]

              } else {
                set CC_USED "NO"
                set CC_ASYNC "N/A"
                set CC_RATIO "N/A"
              }

            } else {

              #Check to see if CC exists since SAMP is not in interconnect
              set CHECK_CC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$MASTER_CC_NUMBER"]

              set CC_EXIST [get_bd_cells $CHECK_CC_CELL_NAME -quiet]

              set CC_EXIST_VALUE [string match $CC_EXIST $EMPTY_VALUE]


              if {$CC_EXIST_VALUE == 0} {
                set CC_USED "YES"
                set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CHECK_CC_CELL_NAME]]
                set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CHECK_CC_CELL_NAME]]

              } else {
                set CC_USED "NO"
                set CC_ASYNC "N/A"
                set CC_RATIO "N/A"
              }
            }
          }
        }

    } else {

      #Check to see if CC exists since SAMP is not in interconnect
      set CHECK_CC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$MASTER_CC_NUMBER"]

      set CC_EXIST [get_bd_cells $CHECK_CC_CELL_NAME -quiet]

      set CC_EXIST_VALUE [string match $CC_EXIST $EMPTY_VALUE]

      if {$CC_EXIST_VALUE == 0} {
        set CC_USED "YES"
        set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CHECK_CC_CELL_NAME]]
        set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CHECK_CC_CELL_NAME]]

      } else {

        set CC_USED "NO"
        set CC_ASYNC "N/A"
        set CC_RATIO "N/A"
      }
      set SAMP_USED "NO"
      set SAMP_SI_WIDTH "N/A"
      set SAMP_MI_WIDTH "N/A"
    }

    #Check to see if protocol converter, must output the block diagram first to generate PC

    set CHECK_PC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$MASTER_PC_NUMBER"]

    #lappend output "The CELL name is $CHECK_PC_CELL_NAME"
    set PC_EXIST [get_bd_cells $CHECK_PC_CELL_NAME -quiet]

    set PC_EXIST_VALUE [string match $PC_EXIST $EMPTY_VALUE]

    if {$PC_EXIST_VALUE == 0} {
      set PROTO_CONV "YES"
      set PC_CELL_NAME_MASTER [concat "$CHECK_PC_CELL_NAME$S_AXI_NAME"]
      set PC_CELL_NAME_SLAVE [concat "$CHECK_PC_CELL_NAME$M_AXI_NAME"]

      set PROTO_S_AXI_PROTO [get_property {CONFIG.PROTOCOL} [get_bd_intf_pins $PC_CELL_NAME_MASTER]]

      set PROTO_M_AXI_PROTO [get_property {CONFIG.PROTOCOL} [get_bd_intf_pins $PC_CELL_NAME_SLAVE]]

    } else {
      set PROTO_CONV "NO"
      set PROTO_S_AXI_PROTO "N/A"

      set PROTO_M_AXI_PROTO "N/A"
    }

    #Report out Interconnect Master settings

    set MASTER_SETTINGS $MASTER_INTERFACE_NAME

    set MASTER_PROPERTY [get_property CONFIG.PROTOCOL [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY

    set MASTER_PROPERTY [get_property CONFIG.READ_WRITE_MODE [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY


    set MASTER_PROPERTY [get_property CONFIG.ADDR_WIDTH [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY


    set MASTER_PROPERTY [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY


    set MASTER_PROPERTY [get_property CONFIG.CLK_DOMAIN [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY


    set MASTER_PROPERTY [get_property CONFIG.FREQ_HZ [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY

    set MASTER_PROPERTY [get_property CONFIG.MAX_BURST_LENGTH [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY

    lappend MASTER_SETTINGS $READ_ISSUE_VALUE


    lappend MASTER_SETTINGS $WRITE_ISSUE_VALUE

    set MASTER_PROPERTY [get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins $MASTER_INTERFACE_NAME]]
    lappend MASTER_SETTINGS $MASTER_PROPERTY

    set tbl [[namespace parent]::Table::Create]
    $tbl title "AXI Master $MASTERS"
    $tbl header [list "name" "PROTO" "MODE" "AW" "DW" "CLK DOMAIN" "FREQ" "MAX BURST" "R ISSUE" "W ISSUE" "NARROW BURST"]
    $tbl addrow $MASTER_SETTINGS
    set output [concat $output [split [$tbl print] \n]  ]
    catch {$tbl destroy}

    unset MASTER_SETTINGS

    set MASTER_INTERCONNECT_SETTINGS $MASTER_NAME

    if {$REG_VALUE == 0} {
       lappend MASTER_INTERCONNECT_SETTINGS "NO"
    } elseif {$REG_VALUE == 1} {
       lappend MASTER_INTERCONNECT_SETTINGS "Outer"
    } elseif {$REG_VALUE == 2} {
       lappend MASTER_INTERCONNECT_SETTINGS "Auto"
    } elseif {$REG_VALUE == 3} {
       lappend MASTER_INTERCONNECT_SETTINGS "Outer and Auto"
    } else {
       lappend MASTER_INTERCONNECT_SETTINGS "Not Known"
    }

    if {$FIFO_VALUE == 0} {
       lappend MASTER_INTERCONNECT_SETTINGS "NO"
    } elseif {$FIFO_VALUE == 1} {
       lappend MASTER_INTERCONNECT_SETTINGS "32-Deep"
    } elseif {$FIFO_VALUE == 2} {
       lappend MASTER_INTERCONNECT_SETTINGS "512-Deep"
    } else {
       lappend MASTER_INTERCONNECT_SETTINGS "Not Known"
    }

    lappend MASTER_INTERCONNECT_SETTINGS $PROTO_CONV

    lappend MASTER_INTERCONNECT_SETTINGS $PROTO_S_AXI_PROTO

    lappend MASTER_INTERCONNECT_SETTINGS $PROTO_M_AXI_PROTO

    lappend MASTER_INTERCONNECT_SETTINGS $SAMP_USED

    lappend MASTER_INTERCONNECT_SETTINGS $SAMP_SI_WIDTH

    lappend MASTER_INTERCONNECT_SETTINGS $SAMP_MI_WIDTH

    lappend MASTER_INTERCONNECT_SETTINGS $CC_USED

    lappend MASTER_INTERCONNECT_SETTINGS $CC_ASYNC

    #No Ratio if async
    if {$CC_ASYNC == 0} {
      lappend MASTER_INTERCONNECT_SETTINGS $CC_RATIO
    } else {
      lappend MASTER_INTERCONNECT_SETTINGS "N/A"
    }

    set tbl [[namespace parent]::Table::Create]
    $tbl title "AXI Interconnect Slot $MASTER_NUMBER"
    $tbl header [list "name" "REG" "FIFO" "PC" "S_AXI_PROTO" "M_AXI_PROTO" "DW_CONV" "S_AXI_DW" "M_AXI_DW" "CC" "CC_ASYNC" "CC_RATIO"]
    $tbl addrow $MASTER_INTERCONNECT_SETTINGS
    set output [concat $output [split [$tbl print] \n]  ]
    catch {$tbl destroy}

    unset MASTER_INTERCONNECT_SETTINGS

    lappend output " "
  }

  lappend output " "
  lappend output " "

  #Obtain Proper Name for Slave connection Into Interconnect
  for {set SLAVES 0} {$SLAVES < $NUM_MI} {incr SLAVES 1} {

    #Check to see if slave is less then 9, since a 0 needs to be before
    if {$SLAVES <= 9} {
      set SLAVE_NUMBER "_M0${SLAVES}"
      set SLAVE_PIN_NUMBER "/M0${SLAVES}"
      set SLAVE_CONFIG_NUMBER "CONFIG.M0${SLAVES}"
      set SLAVE_PC_NUMBER "/m0${SLAVES}_couplers/auto_pc"
      set SLAVE_SAMP_NUMBER "/m0${SLAVES}_couplers/auto_*s*"
      set SLAVE_SAMP_NUMBER_RS "/m0${SLAVES}_couplers/auto_rs"
      set SLAVE_CC_NUMBER "/m0${SLAVES}_couplers/auto_cc"

    } else {
      set SLAVE_NUMBER "_M${SLAVES}"
      set SLAVE_PIN_NUMBER "/M${SLAVES}"
      set SLAVE_CONFIG_NUMBER "CONFIG.M${SLAVES}"
      set SLAVE_PC_NUMBER "/m${SLAVES}_couplers/auto_pc"
      set SLAVE_SAMP_NUMBER "/m${SLAVES}_couplers/auto_*s*"
      set SLAVE_SAMP_NUMBER_RS "/m${SLAVES}_couplers/auto_rs"
      set SLAVE_CC_NUMBER "/m${SLAVES}_couplers/auto_cc"

    }

    #Setup Config variables
    set CONFIG_REG_NAME [concat "$SLAVE_CONFIG_NUMBER$HAS_REG"]
    set CONFIG_FIFO_NAME [concat "$SLAVE_CONFIG_NUMBER$HAS_FIFO"]
    set CONFIG_M_READ_ISSUE [concat "$SLAVE_CONFIG_NUMBER$READ_ISSUE"]
    set CONFIG_M_WRITE_ISSUE [concat "$SLAVE_CONFIG_NUMBER$WRITE_ISSUE"]


    #Setup Slave Instance Name and see if monitor being used
    #get_bd_intf_nets -of_objects [get_bd_intf_pin /axi_interconnect_1/M02_AXI]


    set SLAVE_PIN_NAME [concat ${INTERCONNECT_NAME_VAR}${SLAVE_PIN_NUMBER}$AXI_NAME]

    set SLAVE_NAME_OUTPUT [concat ${INTERCONNECT_NAME_VAR}${SLAVE_NUMBER}$AXI_NAME]

    set SLAVE_NAME [get_bd_intf_nets -of_objects [get_bd_intf_pin $SLAVE_PIN_NAME]]


    set SLAVE_INTERFACE_NAMES [get_bd_intf_pins -of_objects [get_bd_intf_net $SLAVE_NAME]]


    foreach ARRAY_VALUE $SLAVE_INTERFACE_NAMES {

      set STRING_COMPARE [string match $SLAVE_PIN_NAME $ARRAY_VALUE]
      #lappend output " $SLAVE_PIN_NAME $ARRAY_VALUE $STRING_COMPARE"

      #Check and make sure master is not a monitor
      set SLAVE_MODE [get_property MODE [get_bd_intf_pins $ARRAY_VALUE]]
      #lappend output "Slave mode is $SLAVE_MODE"
      #lappend output "mon mode is $MON_MODE"

      set MODE_STRING_COMPARE [string match $SLAVE_MODE $MON_MODE]

      #lappend output "Slave mode compare is $MODE_STRING_COMPARE"
      if {$STRING_COMPARE == 0} {
        if {$MODE_STRING_COMPARE == 0} {
          set SLAVE_INTERFACE_NAME $ARRAY_VALUE
        }
      }

    }

    #lappend output "reg name $CONFIG_REG_NAME"

    #lappend output "fifo name $CONFIG_FIFO_NAME"

    set REG_VALUE [get_property $CONFIG_REG_NAME [get_bd_cells ${INTERCONNECT_NAME_VAR}]]
    set FIFO_VALUE [get_property $CONFIG_FIFO_NAME [get_bd_cells ${INTERCONNECT_NAME_VAR}]]

  if {$XBAR_EXIST != ""} {
    set READ_ACCEPT_VALUE [get_property $CONFIG_M_READ_ISSUE [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar]]
    set WRITE_ACCEPT_VALUE [get_property $CONFIG_M_WRITE_ISSUE [get_bd_cells ${INTERCONNECT_NAME_VAR}/xbar]]
    } else {
      set READ_ACCEPT_VALUE "N/A"
      set WRITE_ACCEPT_VALUE "N/A"      
    }
    
    #Check to see if sampler up or down is used, also check clock conversion as well in module or CC

    set CHECK_SAMP_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$SLAVE_SAMP_NUMBER"]
    set SAMP_EXIST [get_bd_cells $CHECK_SAMP_CELL_NAME -quiet]
    set SAMP_EXIST_VALUE [string match $SAMP_EXIST $EMPTY_VALUE]




    if {$SAMP_EXIST_VALUE == 0} {
      set CELL_NAMES [get_bd_cells $CHECK_SAMP_CELL_NAME]
      foreach CELL $CELL_NAMES {

        #Since RS will be confused for samplers, add extra case
        set CHECK_RS_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$SLAVE_SAMP_NUMBER_RS"]
        set RS_EXIST_VALUE [string match $CELL $CHECK_RS_CELL_NAME]


        if {$RS_EXIST_VALUE == 1} {
         #Don't Do Anything yet
        } else {
          set SAMP_USED "YES"
          set SAMP_SI_WIDTH [get_property {CONFIG.SI_DATA_WIDTH} [get_bd_cells $CELL]]

          set SAMP_MI_WIDTH [get_property {CONFIG.MI_DATA_WIDTH} [get_bd_cells $CELL]]



          if {$FIFO_VALUE > 0} {

            #See if both clocks connected, if so CC is used
            set M_CLK [get_bd_pin $CELL/m_axi_aclk -quiet]
            set M_CLK_EXIST_VALUE [string match $M_CLK $EMPTY_VALUE]

            set S_CLK [get_bd_pin $CELL/s_axi_aclk -quiet]
            set S_CLK_EXIST_VALUE [string match $S_CLK $EMPTY_VALUE]

            #Compare Interconnect Frequency to Slave frequency, if not equal CC is used
            if {[string equal $M_CLK_EXIST_VALUE $S_CLK_EXIST_VALUE]} {
              set CC_USED "YES"
              set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CELL]]
              set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CELL]]

            } else {
              set CC_USED "NO"
              set CC_ASYNC "N/A"
              set CC_RATIO "N/A"
            }

          } else {

            #Check to see if CC exists since SAMP is not in interconnect
            set CHECK_CC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$SLAVE_CC_NUMBER"]

            set CC_EXIST [get_bd_cells $CHECK_CC_CELL_NAME -quiet]

            set CC_EXIST_VALUE [string match $CC_EXIST $EMPTY_VALUE]


            if {$CC_EXIST_VALUE == 0} {
              set CC_USED "YES"
              set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CHECK_CC_CELL_NAME]]
              set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CHECK_CC_CELL_NAME]]

            } else {
              set CC_USED "NO"
              set CC_ASYNC "N/A"
              set CC_RATIO "N/A"
            }
          }
        }
      }
    } else {

      #Check to see if CC exists since SAMP is not in interconnect
      set CHECK_CC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$SLAVE_CC_NUMBER"]

      set CC_EXIST [get_bd_cells $CHECK_CC_CELL_NAME -quiet]

      set CC_EXIST_VALUE [string match $CC_EXIST $EMPTY_VALUE]


      if {$CC_EXIST_VALUE == 0} {
        set CC_USED "YES"
        set CC_ASYNC [get_property {CONFIG.ACLK_ASYNC} [get_bd_cells $CHECK_CC_CELL_NAME]]
        set CC_RATIO [get_property {CONFIG.ACLK_RATIO} [get_bd_cells $CHECK_CC_CELL_NAME]]

      } else {
        set CC_USED "NO"
        set CC_ASYNC "N/A"
        set CC_RATIO "N/A"
      }
      set SAMP_USED "NO"
      set SAMP_SI_WIDTH "N/A"
      set SAMP_MI_WIDTH "N/A"
    }

    #Check to see if protocol converter, must output the block diagram first to generate PC

    set CHECK_PC_CELL_NAME [concat "$INTERCONNECT_NAME_VAR$SLAVE_PC_NUMBER"]

    #lappend output "The CELL name is $CHECK_PC_CELL_NAME"
    set PC_EXIST [get_bd_cells $CHECK_PC_CELL_NAME -quiet]

    set PC_EXIST_VALUE [string match $PC_EXIST $EMPTY_VALUE]

    if {$PC_EXIST_VALUE == 0} {
      set PROTO_CONV "YES"
      set PC_CELL_NAME_MASTER [concat "$CHECK_PC_CELL_NAME$S_AXI_NAME"]
      set PC_CELL_NAME_SLAVE [concat "$CHECK_PC_CELL_NAME$M_AXI_NAME"]

      set PROTO_S_AXI_PROTO [get_property {CONFIG.PROTOCOL} [get_bd_intf_pins $PC_CELL_NAME_MASTER]]


      set PROTO_M_AXI_PROTO [get_property {CONFIG.PROTOCOL} [get_bd_intf_pins $PC_CELL_NAME_SLAVE]]

    } else {
      set PROTO_CONV "NO"
      set PROTO_S_AXI_PROTO "N/A"

      set PROTO_M_AXI_PROTO "N/A"
    }

    set SLAVE_SETTINGS $SLAVE_INTERFACE_NAME

    set SLAVE_PROPERTY [get_property CONFIG.PROTOCOL [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.READ_WRITE_MODE [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.ADDR_WIDTH [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.CLK_DOMAIN [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.FREQ_HZ [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set SLAVE_PROPERTY [get_property CONFIG.MAX_BURST_LENGTH [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    lappend SLAVE_SETTINGS $READ_ACCEPT_VALUE

    lappend SLAVE_SETTINGS $WRITE_ACCEPT_VALUE

    set SLAVE_PROPERTY [get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins $SLAVE_INTERFACE_NAME]]
    lappend SLAVE_SETTINGS $SLAVE_PROPERTY

    set tbl [[namespace parent]::Table::Create]
    $tbl title "AXI Slave $SLAVES"
    $tbl header [list "name" "PROTO" "MODE" "AW" "DW" "CLK DOMAIN" "FREQ" "MAX BURST" "R ACCEPT" "W ACCEPT" "NARROW BURST"]
    $tbl addrow $SLAVE_SETTINGS
    set output [concat $output [split [$tbl print] \n]  ]
    catch {$tbl destroy}

    unset SLAVE_SETTINGS

    set SLAVE_INTERCONNECT_SETTINGS $SLAVE_NAME_OUTPUT

    if {$REG_VALUE == 0} {
      lappend SLAVE_INTERCONNECT_SETTINGS "NO"
    } elseif {$REG_VALUE == 1} {
      lappend SLAVE_INTERCONNECT_SETTINGS "Outer"
    } elseif {$REG_VALUE == 2} {
      lappend SLAVE_INTERCONNECT_SETTINGS "Auto"
    } elseif {$REG_VALUE == 3} {
      lappend SLAVE_INTERCONNECT_SETTINGS "Outer and Auto"
    } else {
      lappend SLAVE_INTERCONNECT_SETTINGS "Not Known"
    }

    if {$FIFO_VALUE == 0} {
      lappend SLAVE_INTERCONNECT_SETTINGS "NO"
    } elseif {$FIFO_VALUE == 1} {
      lappend SLAVE_INTERCONNECT_SETTINGS "32-Deep"
    } elseif {$FIFO_VALUE == 2} {
      lappend SLAVE_INTERCONNECT_SETTINGS "512-Deep"
    } else {
      lappend SLAVE_INTERCONNECT_SETTINGS "Not Known"
    }

    lappend SLAVE_INTERCONNECT_SETTINGS $PROTO_CONV

    lappend SLAVE_INTERCONNECT_SETTINGS $PROTO_S_AXI_PROTO

    lappend SLAVE_INTERCONNECT_SETTINGS $PROTO_M_AXI_PROTO

    lappend SLAVE_INTERCONNECT_SETTINGS $SAMP_USED

    lappend SLAVE_INTERCONNECT_SETTINGS $SAMP_SI_WIDTH

    lappend SLAVE_INTERCONNECT_SETTINGS $SAMP_MI_WIDTH

    lappend SLAVE_INTERCONNECT_SETTINGS $CC_USED

    lappend SLAVE_INTERCONNECT_SETTINGS $CC_ASYNC

    #No Ratio if async
    if {$CC_ASYNC == 0} {
      lappend SLAVE_INTERCONNECT_SETTINGS $CC_RATIO
    } else {
      lappend SLAVE_INTERCONNECT_SETTINGS "N/A"
    }

    set tbl [[namespace parent]::Table::Create]
    $tbl title "AXI Interconnect Slot $SLAVE_PIN_NUMBER"
    $tbl header [list "name" "REG" "FIFO" "PC" "M_AXI_PROTO" "S_AXI_PROTO" "DW_CONV" "M_AXI_DW" "S_AXI_DW" "CC" "CC_ASYNC" "CC_RATIO"]
    $tbl addrow $SLAVE_INTERCONNECT_SETTINGS
    set output [concat $output [split [$tbl print] \n]  ]
    catch {$tbl destroy}

    unset SLAVE_INTERCONNECT_SETTINGS
    lappend output " "

  }
  lappend output " "

  return $output
}

