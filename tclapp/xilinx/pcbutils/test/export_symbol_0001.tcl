# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

set part_list [list xc7vx485tffg1761-2 xc7k70tfbg676-3 xc7a200tfbg676-2L xc7z045ffg900-1 \
                    xcvu095-ffvb1760-1L-i-es2 xcku040-ffva1156-1L-i \
                    xcvu9p-flva2104-2LV-e-es1 xcku9p-ffve900-2LV-e-es1 xczu9eg-ffvb1156-2LV-e-es1]

foreach part $part_list {
  regexp {xc(vu|ku|zu|7vx|7k|7a|7z)(\d+)(t|p|eg|)} $part mtch fam siz ext
  set prj_name ${fam}${siz}${ext}
  file mkdir ./build/$prj_name
  cd ./build/$prj_name
  create_project -force -part $part ./$prj_name
  set_property design_mode PinPlanning [current_fileset]
  open_io_design -name io_1

  if {[catch { ::tclapp::xilinx::pcbutils::export_symbol -file symbol_${prj_name}.csv} catchErrorString]} {
    close_design
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
  }

  close_project
  cd ../../
}

return 0
