set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
#set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

#puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
#lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name            "ngc_test_0001"
set result_dir      [ file normalize [ file join $file_dir "ngc_results" ] ]
set verilog_dir     [ file join $result_dir "verilog" ]
set edif_dir        [ file join $result_dir "edif" ]
set data_origin_dir [ file normalize [ file join $file_dir "data" ] ]
set data_dir        [ file join $result_dir "data" ]
set source_ngc      [ file join $data_dir "out_ddr_flop.ngc" ]

if { [ file exists $result_dir ] } {
  file delete -force $result_dir 
}
file mkdir $result_dir
file copy $data_origin_dir $data_dir
file mkdir $verilog_dir
file mkdir $edif_dir


# Check business rules
if { ! [ catch { convert_ngc } ] } { error "Didn't receive expected error with: no file specified" }
if { ! [ catch { convert_ngc $source_ngc -format bad } ] } { error "Didn't receive expected error with: -format bad" }


# Output goes to source (NGC) location and works without project
set verilog_src_expected_out [ file join $data_dir "out_ddr_flop.v" ]
convert_ngc $source_ngc -format verilog
if { ! [ file exists $verilog_src_expected_out ] } { error "Didn't find '${verilog_expected_out}', but converted and it passed!" }

set edif_src_expected_out [ file join $data_dir "out_ddr_flop.edn" ]
convert_ngc $source_ngc ; # -format edif is default, checking here that also works
if { ! [ file exists $edif_src_expected_out ] } { error "Didn't find '${edif_expected_out}', but converted and it passed!" }


# Verilog
set verilog_expected_out [ file join $verilog_dir "out_ddr_flop.v" ]
create_project $name $verilog_dir -force

if { [ file exists $verilog_expected_out ] } { error "Found '${verilog_expected_out}', but we haven't converted yet!" }
convert_ngc $source_ngc -format vErIlOg -output_dir $verilog_dir
if { [ llength [ get_files ] ] != 0 } { error "Files have been added to new project, and shouldn't have been: [ get_files ]" }
if { ! [ file exists $verilog_expected_out ] } { error "Didn't find '${verilog_expected_out}', but converted and it passed!" }

if { ! [ catch { convert_ngc $source_ngc -format "verilog" -output_dir $verilog_dir } ] } { error "Didn't receive expected error with: -format verilog <no -force>, when output already exists" }
convert_ngc $source_ngc -format {Verilog} -output_dir $verilog_dir -force -add_to_project 
if { [ llength [ get_files $verilog_expected_out ] ] != 1 } { error "Verilog file was not added to project, and should have been (-add_to_project): [ get_files ]" }

close_project


# EDIF
set edif_expected_out [ file join $edif_dir "out_ddr_flop.edn" ]
create_project $name $edif_dir -force

if { [ file exists $edif_expected_out ] } { error "Found '${edif_expected_out}', but we haven't converted yet!" }
convert_ngc $source_ngc -format eDiF -output_dir $edif_dir
if { [ llength [ get_files ] ] != 0 } { error "Files have been added to new project, and shouldn't have been: [ get_files ]" }
if { ! [ file exists $edif_expected_out ] } { error "Didn't find '${edif_expected_out}', but converted and it passed!" }

if { ! [ catch { convert_ngc $source_ngc -format "edif" -output_dir $edif_dir } ] } { error "Didn't receive expected error with: -format edif <no -force>, when output already exists" }
convert_ngc $source_ngc -format {edif} -output_dir $edif_dir -force -add_to_project
if { [ llength [ get_files $edif_expected_out ] ] != 1 } { error "EDIF file was not added to project, and should have been (-add_to_project): [ get_files ]" }

close_project

# cleanup if we didn't error
file delete -force $result_dir

puts "done.\n  completed successfully, errors above were expected and were negative tests"

