########################################################################################
## 01/07/2016 - Initial release (Tony Scarangella)
########################################################################################
## ---------------------------------------------------------------------
## Description
##    This proc exports a device csv file that can be directly copied and pasted to Orcad 
##    Capture part generation spreadsheet to generate a multi-part symbol for the selected 
#     device.
## 
##    Orcad 10.5 or newer is required because the "New Part from Spreadsheet" function 
##    was first added to version 10.5. For users with older versions of Orcad, the 
##    "Tools->Generate Part" function in Orcad should still work
##    (http://www.orcad.com/documents/community.faqs/capture/cap03022.aspx) with simple 
##    changes to the CSV file exported. 
##
## Author: Tony Scarangella
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## --------------------------------------------------------------------- 
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::pcbutils {
  namespace export export_symbol
  
}

proc tclapp::xilinx::pcbutils::export_symbol { args } {
  # Summary: Export_symbol information

  # Argument Usage:
  # [-verbose]: Verbose mode
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-single_bank]: Distribute one bank on a single symbol 
  # [-format <arg>]: Set output file format. Orcad csv is the only format supported
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, projutils

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  proc lshift {inputlist} {
    upvar $inputlist argv
    set arg  [lindex $argv 0]
    set argv [lrange $argv 1 end]
    return $arg
  }

  set error 0
  set filename {}
  set mode {w}
  set help 0
  set returnString 0
  set verbose 0
  set single_bank 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -file -
      {^-f(i(le?)?)?$} {
           set filename [lshift args]
           if {$filename == {}} {
             puts " -E- no filename specified."
             incr error
           }
      }
      -append -
      {^-a(p(p(e(nd?)?)?)?)?$} {
           set mode {a}
      }
      -single_bank -
      {^-s(i(n(g(le_bank?)?)?)?)?$} {
           set single_bank 1
      }
      -format -
      {^-f(o(r(m(at?)?)?)?)?$} {
           set format [lshift args]
           if {$format == {}} {
             set format orcad
             puts " Format set to Orcad csv. This is currently the only supported format"
           }	else {
             puts " Format set to Orcad csv. This is currently the only supported format"
           }
      }
      -return_string -
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
      }
      -verbose -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
           set verbose 1
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} -
      -help -
      {^-h(e(lp?)?)?$} {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }
  
  if {$help} {
    puts [format {
    Usage: export_symbol
                [-file  <arg>]       - Report file name
                [-append]            - Append to file
                [-single_bank]       - Distribute one bank on a single symbol
                [-format <arg>]      - Set output file format. Orcad csv is the only format supported
                [-verbose]           - Verbose mode
                [-return_string]     - Return report as string
                [-usage|-u]          - This help message
                
    Description: Export Orcad Symbol table

       This command exports a device csv file that can be directly copied 
       and pasted to Orcad Capture part generation spreadsheet to generate 
       a multi-part symbol for the selected	device.
    
    Example:
       export_symbol
       export_symbol -verbose -file symbol.csv
    } ]
    # HELP -->
    return {}
  }
  
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$filename !={}} {
    set output [list]
    set device [get_property part [current_project]]
    set start [clock seconds] 
    set systemTime [clock seconds]      ; # capture current time
    set total_io [llength [get_package_pins]]
    set file_rows 0
				set gnd_pins_qty [llength [get_package_pins -filter { PIN_FUNC == GND } ]]
    array unset symbol_array
    
    #FOR ALL PINS FIND UNIQUE PIN_FUNC
    set pin_function ""
    foreach x [get_package_pins] {
      lappend pin_function [get_property PIN_FUNC [get_package_pins $x]]
    }
    set pin_function_non_bank ""
    foreach x [get_package_pins] { 
      if {[get_property BANK [get_package_pins $x]] == ""} {
        lappend pin_function_non_bank [get_property PIN_FUNC [get_package_pins $x]]
      }
    }
    set pin_function_unique [lsort -unique $pin_function]
    set pin_function_non_bank_unique [lsort -unique $pin_function_non_bank]

    #FOR EACH BANK FIND PINS AND CREATE BANK ARRAY
    array unset bank_array
    foreach x [lsort -dictionary [get_iobanks]] { 
      foreach y [get_package_pins] {
        if {$x == [get_property BANK [get_package_pins $y]]} {
    	  lappend bank_array($x) "$y [get_property PIN_FUNC [get_package_pins $y]]"
        }
      }
    }

    #FOR EACH NON-BANK FIND PINS AND CREATE NON BANK ARRAY
    array unset non_bank_array
    foreach x $pin_function_non_bank_unique { 
      foreach y [get_package_pins] {
        if {$x == [get_property PIN_FUNC [get_package_pins $y]]} {
    	  lappend non_bank_array($x) "$y [get_property PIN_FUNC [get_package_pins $y]]"
        }
      }
    }

    #FIND NON BANK PIN_FUNC EQUAL TO 1 AND MOVE TO BANK0
    foreach x $pin_function_non_bank_unique {
      if {[llength $non_bank_array($x)] == 1} {
    	lappend bank_array(0) "[get_package_pins -quiet -filter "PIN_FUNC == $x"] $x"
    	unset non_bank_array($x)
      }	
    }

    set pin_function_non_bank_unique_reduced [array name non_bank_array]

    if {$verbose} {
      foreach x [lsort -dictionary [get_iobanks]] { puts "([llength $bank_array($x)]):$bank_array($x)"}
      foreach x [lsort -dictionary $pin_function_non_bank_unique_reduced] { puts "([llength $non_bank_array($x)]):$non_bank_array($x)"}
      #foreach x [lsort -dictionary $non_bank_array] { puts "([llength $non_bank_array($x)]):$non_bank_array($x)"}
      puts "VERBOSE: parray bank_array"
      puts "VERBOSE: parray non_bank_array"
    }

  		#INPUT SYMBOL PIN DIRECTIONS
    set dir_in [get_package_pins -quiet -filter { PIN_FUNC =~ PROGRAM* || \
                                                  PIN_FUNC =~ TCK* || \
                                                  PIN_FUNC =~ TDI* || \
                                                  PIN_FUNC =~ TMS* || \
                                                  PIN_FUNC =~ CFGBVS* || \
                                                  PIN_FUNC =~ PUDC* || \
                                                  PIN_FUNC =~ M0* || \
                                                  PIN_FUNC =~ M1* || \
                                                  PIN_FUNC =~ M2* || \
                                                  PIN_FUNC =~ DXP* || \
                                                  PIN_FUNC =~ DXN* || \
                                                  PIN_FUNC =~ POR_OVERRIDE* || \
                                                  PIN_FUNC =~ VP* || \
                                                  PIN_FUNC =~ VN* || \
                                                  PIN_FUNC =~ RSVD* || \
                                                  PIN_FUNC =~ NC* || \
                                                  PIN_FUNC =~ MGTHRX* || \
                                                  PIN_FUNC =~ MGTPRX* || \
                                                  PIN_FUNC =~ MGTXRX* || \
                                                  PIN_FUNC =~ MGTYRX* || \
                                                  PIN_FUNC =~ MGTZRX* || \
                                                  PIN_FUNC =~ MGTAVCC* || \
                                                  PIN_FUNC =~ MGTAVTT* || \
                                                  PIN_FUNC =~ MGTVCCAUX* || \
                                                  PIN_FUNC =~ MGTREFCLK* || \
                                                  PIN_FUNC =~ MGTRREF* || \
                                                  PIN_FUNC =~ PS_CLK* || \
                                                  PIN_FUNC =~ PS_DDR_VREF* || \
                                                  PIN_FUNC =~ PS_JTAG_TCK* || \
                                                  PIN_FUNC =~ PS_JTAG_TDI* || \
                                                  PIN_FUNC =~ PS_JTAG_TMS* || \
                                                  PIN_FUNC =~ PS_MODE* || \
                                                  PIN_FUNC =~ PS_PADI* || \
                                                  PIN_FUNC =~ PS_POR_B* || \
                                                  PIN_FUNC =~ PS_PROG_B* || \
                                                  PIN_FUNC =~ PS_REF_CLK* || \
                                                  PIN_FUNC =~ PS_SRST_B* || \
                                                  PIN_FUNC =~ PS_DDR_ALERT_N* || \
                                                  PIN_FUNC =~ PS_MGTREFCLK* || \
                                                  PIN_FUNC =~ PS_MGTRREF* || \
                                                  PIN_FUNC =~ PS_MIO_VREF*}] 
     set dir_in_pf_list ""
     foreach x $dir_in {lappend dir_in_pf_list [get_property PIN_FUNC [get_package_pins $x]]}

					#OUTPUT SYMBOL PIN DIRECTIONS
     set dir_out [get_package_pins -quiet -filter { PIN_FUNC =~ PUDC* || \
                                                    PIN_FUNC =~ TDO* || \
                                                    PIN_FUNC =~ MGTHTX* || \
                                                    PIN_FUNC =~ MGTPTX* || \
                                                    PIN_FUNC =~ MGTXTX* || \
                                                    PIN_FUNC =~ MGTYTX* || \
                                                    PIN_FUNC =~ MGTZTX* || \
                                                    PIN_FUNC =~ MGTPTX* || \
                                                    PIN_FUNC =~ PS_DONE* || \
                                                    PIN_FUNC =~ PS_ERROR_OUT* || \
                                                    PIN_FUNC =~ PS_ERROR_STATUS* || \
                                                    PIN_FUNC =~ PS_JTAG_TDO* || \
                                                    PIN_FUNC =~ PS_PADO* || \
                                                    PIN_FUNC =~ PS_DDR_ACT_N* || \
                                                    PIN_FUNC =~ PS_DDR_A* || \
                                                    PIN_FUNC =~ PS_DDR_BA* || \
                                                    PIN_FUNC =~ PS_DDR_BG* || \
                                                    PIN_FUNC =~ PS_DDR_CAS_B || \
                                                    PIN_FUNC =~ PS_DDR_CK* || \
                                                    PIN_FUNC =~ PS_DDR_CS* || \
                                                    PIN_FUNC =~ PS_DDR_DM* || \
                                                    PIN_FUNC =~ PS_DDR_DRST_B || \
                                                    PIN_FUNC =~ PS_DDR_ODT* || \
                                                    PIN_FUNC =~ PS_DDR_PARITY* || \
                                                    PIN_FUNC =~ PS_DDR_RAS_B || \
                                                    PIN_FUNC =~ PS_DDR_RAM_RST_N* || \
                                                    PIN_FUNC =~ PS_DDR_WE_B || \
                                                    PIN_FUNC =~ PS_DDR_VR*}]
     set dir_out_pf_list ""
     foreach x $dir_out {lappend dir_out_pf_list [get_property PIN_FUNC [get_package_pins $x]]}

					#POWER SYMBOL PIN DIRECTIONS
     set pwr [get_package_pins -quiet -filter { PIN_FUNC =~ GND* || \
                                                PIN_FUNC =~ VCCADC* || \
                                                PIN_FUNC =~ MGTAVCC* || \
                                                PIN_FUNC =~ MGTAVTT* || \
                                                PIN_FUNC =~ MGTVCCAUX* || \
                                                PIN_FUNC =~ VCCO_* || \
                                                PIN_FUNC =~ VCCADC* || \
                                                PIN_FUNC =~ VCCAUX* || \
                                                PIN_FUNC =~ VCCBRAM* || \
                                                PIN_FUNC =~ VCCINT*}]
     set pwr_pf_list ""
     foreach x $pwr {lappend pwr_pf_list [get_property PIN_FUNC [get_package_pins $x]]}
     #BIDIRECTIONAL NOT USED (DEFAULT DIRECTION)

   		#OUTPUT FILE GENERATION SECTION
     set per_bank_io_total ""
     #set bank_cnt 0
     set section 1
     set last_section -1
     set symbol_side Left
     set io_io 0
     set mgt_io 0
     set ps_io 0
     #LOOP THROUGH EACH BANK
     foreach x [lsort -dictionary [array name bank_array]] {
       foreach y $bank_array($x) {
         #RESYNCHRONIZE SYMBOL SIDE TO LEFT AFTER PROCESSING IO_, MGT OR PS_
         if {[regexp {^IO_} [lindex $y 1]] && [get_property BANK [get_package_pins [lindex $y 0]]] != 0 && $io_io == 0} {
           set symbol_side Left
           set io_io 1
           incr section
         } elseif {[regexp {^MGT} [lindex $y 1]] && [get_property BANK [get_package_pins [lindex $y 0]]] != 0 && $mgt_io == 0} {
           set symbol_side Left
           set mgt_io 1
           #CHECK FOR UNEVEN IO_ TO MGT BANK BOUNDRIES
           if {$last_section == $section} {
             incr section
           }
         }	elseif {[regexp {^PS_} [lindex $y 1]] && [get_property BANK [get_package_pins [lindex $y 0]]] != 0 && $ps_io == 0} {
           set symbol_side Left
           set ps_io 1
         }	
									#PROVIDE SYMBOL PIN DIRECTION
         if {[lsearch $dir_in_pf_list [lindex $y 1]] != -1} {
           lappend output "[lindex $y 0],[lindex $y 1],Input,1,Line,1,Left,$section"
        	  lappend symbol_array($section) "[lindex $y 0]"
    							set write_file 1
    					  incr file_rows
         } elseif {[lsearch $dir_out_pf_list [lindex $y 1]] != -1} {
            lappend output "[lindex $y 0],[lindex $y 1],Output,1,Line,1,Right,$section"
         	  lappend symbol_array($section) "[lindex $y 0]"
     							set write_file 1
     					  incr file_rows
         } elseif {[lsearch $pwr_pf_list [lindex $y 1]] != -1} {
            lappend output "[lindex $y 0],[lindex $y 1],Power,1,Line,1,Left,$section"
         	  lappend symbol_array($section) "[lindex $y 0]"
     							set write_file 1
     					  incr file_rows
         }	else {
            lappend output "[lindex $y 0],[lindex $y 1],Bidirectional,1,Line,1,$symbol_side,$section"
         	  lappend symbol_array($section) "[lindex $y 0]"
     							set write_file 1
     					  incr file_rows
   						}
       }
       if {$single_bank == 0 && $section >= 2 && $symbol_side == "Left"} {
         set symbol_side Right
         set last_section $section
       } elseif {$single_bank == 0 && $section >= 2 && $symbol_side == "Right"} {
         set symbol_side Left
         set last_section $section
         incr section
       } 
     }

     #PROCESS THROUGH EACH NON BANK PIN (POWER GND)
     set symbol_side Left
     set last_gnd_right -1 
     set first_gnd_left -1 
					set pin_fun_processed GND
     foreach x [lsort -dictionary [array name non_bank_array]] {
       set pwr_rows 0
       set pin_fun [string range $x 0 2]
							#KEEP POWER FUNCTION IN THE SAME SYMBOL (GND'S TOGETHER, MGT TOGETHER, VCC TOGETHER)
       if {$pin_fun != $pin_fun_processed && $pwr_rows == 0} {
         incr section
         set pwr_rows 1
         set pin_fun_processed $pin_fun
       }	
							#LOOP THROUGH EACH PIN OF PIN_FUNC ARRAY
       foreach y $non_bank_array($x) {
         #CREATE 2 SYMBOLS FOR GROUND PINS
         if {[regexp {GND} [lindex $y 1]] } {
           if {$pwr_rows <= [expr $gnd_pins_qty * 0.25]} {
             set symbol_side Left
           } elseif {$pwr_rows >= [expr $gnd_pins_qty * 0.25] && $pwr_rows <= [expr $gnd_pins_qty * 0.50]} {
             set symbol_side Right
             set last_gnd_right $pwr_rows 
           } elseif {$pwr_rows >= [expr $gnd_pins_qty * 0.50] && $pwr_rows <= [expr $gnd_pins_qty * 0.75]} {
             set symbol_side Left
             set first_gnd_left $pwr_rows 
           } elseif {$pwr_rows >= [expr $gnd_pins_qty * 0.75] && $pwr_rows <= $gnd_pins_qty} {
             set symbol_side Right
           }
           incr pwr_rows
           set pin_fun_processed $pin_fun
         } else {
           set symbol_side Left
         }
         if {[expr $last_gnd_right + 1] == $first_gnd_left && $pin_fun == "GND"} {
           incr section
         }	
         #FOR VCCINT PLACE ON RIGHT SIDE OF SYMBOL
         if {[regexp {^VCCINT} [lindex $y 1]]} {
           set symbol_side Right
         }
       lappend output "[lindex $y 0],[lindex $y 1]_[lindex $y 0],Power,1,Line,1,$symbol_side,$section"
    	  lappend symbol_array($section) "[lindex $y 0]"
     		incr file_rows
       }
     }

    if {$verbose} {
      puts "VERBOSE: Part Number: $device"
      puts "VERBOSE: Number of pins: ([llength [get_package_pins]])"
      puts "VERBOSE: Number of BANKs: ([llength [get_iobanks]])-([get_iobanks])"
      puts "VERBOSE: [parray bank_array]"
      puts "VERBOSE: [parray non_bank_array]"
      puts "VERBOSE: [parray symbol_array]"
    }

    #VERIFY THAT THE NUMBER OF IO'S IS EQUAL TO THE NUMNER OF ROWS WRITTEN.
    if {$total_io != $file_rows} {
      puts "ERROR: Date: [clock format $systemTime -format %D] Compile time: [expr ([clock seconds]-$start)/3600] hour(h), [expr (([clock seconds]-$start)%3600)/60] minute(m) and [expr (([clock seconds]-$start)%3600)%60] second(s)."
      puts "ERROR: Part Number: $device"
      puts "ERROR: The package IO count total_io is not equal to the number of symbol pins generated ($file_rows) Difference([expr $total_io - $file_rows])"
      puts "ERROR: [parray bank_array]"
      puts "ERROR: [parray non_bank_array]"
      puts "ERROR: [parray symbol_array]"
    } else {
      puts "INFO: This file is automatically generated by export_symbol.tcl with Vivado [version -short]"
      puts "INFO: Part Number: $device"
      puts "INFO: Total number of pins in part: $total_io"
      puts "INFO: Total number of symbol pins generated: $file_rows"
      puts "INFO: Total number of symbol generated: $section"
      foreach x [lsort -dictionary [array names symbol_array]] {
        puts "INFO: Symbol # $x contains [llength $symbol_array($x)] pins"
      }
      puts "INFO: Column format: (1)Pin Number, (2)Name, (3)Type, (4)PinVisibility, (5)Shape, (6)Position, (7)Section"
      puts "INFO: Instructions:"
      puts "INFO: 1) Open the csv file orcad_symbol.csv in MS Excel. Scroll down to the last row and take note of the section"
      puts "INFO:    number (the last column). The section number is the number of parts that will be generated for the device."
      puts "INFO: 2) Run Orcad Capture and select \"New Part From Spreadsheet\". On the \"New Part Creation Spreadsheet\""
      puts "INFO:    window, enter a part name in \"Part Name\" box, the section number above in the \"No. of Sections\""
      puts "INFO:    box, and select\"Numeric\" for \"Part Numbering\". This step MUST be done first for the section"
      puts "INFO:    numbers to show up correctly for each pin."
      puts "INFO: 3) Go back to MS Excel and select rows 7 to the last row and columns A to G."
      puts "INFO:    Press CTRL-C to copy the selection to clipboard."
      puts "INFO: 4) Switch to Orcad Capture \"New Part Creation Spreadsheet\" window and select the first cell in the spreadsheet."
      puts "INFO:    Press CTRL-V to paste the clipboard content to the spreadsheet. Click \"Save\" to save the part. You now have a" 
      puts "INFO:    Orcad symbol with multiple parts: one part per bank (including bank 0 and MGT banks),"
      puts "INFO:    one part for each VCC, one part for GND."
      puts "INFO: Date: [clock format $systemTime -format %D] Compile time: [expr ([clock seconds]-$start)/3600] hour(h), [expr (([clock seconds]-$start)%3600)/60] minute(m) and [expr (([clock seconds]-$start)%3600)%60] second(s)."
    }
		}

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [join $output \n]
    close $FH
    puts "\nINFO: Report file [file normalize $filename] has been generated\n"
  } else {
    puts [join $output \n]
  }

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }
}

