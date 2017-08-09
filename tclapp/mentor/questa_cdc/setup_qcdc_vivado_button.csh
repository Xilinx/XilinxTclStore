#! /bin/csh -f

## Description:
## ------------ 
## This script can be used to setup the Vivado GUI button for Questa CDC. It should be located at the same directory of 'write_questa_cdc_script.tcl' script.
## 
## Examples:
## ---------
## <vivado_install_dir>/data/XilinxTclStore/tclapp/mentor/questa_cdc/setup_qcdc_vivado_button.csh
## <questa_cdc_install_dir>/share/fpga_libs/Xilinx/setup_qcdc_vivado_button.csh
## 
## Script created on 08/09/2017 by Islam Ahmed (Mentor Graphics Inc) 

set remove = 0
set usage = "Usage : setup_qcdc_vivado_button.csh [-remove]"
if ( $#argv > 1 ) then
  echo "** Error : Extra number of arguments used"
  echo "$usage"
  exit 1
else if ( $#argv == 1 ) then
  if ( "$argv[1]" == "-remove" ) then
    set remove = 1
  else 
    echo "** Error : Invalid argument specified, usage:"
    echo "$usage"
    exit 1
  endif
endif

set setup_file = "QUESTA_CDC_VIVADO_SETUP_FILE.tcl"
rm -f $setup_file

set rootdir = `dirname $0`       # may be relative path
set rootdir = `cd $rootdir && pwd`    # ensure absolute path

if ( ! -e "$rootdir/write_questa_cdc_script.tcl" ) then
  echo "** Error : Can't find '$rootdir/write_questa_cdc_script.tcl' sript."
  echo "         : The 'setup_qcdc_vivado_button.csh' should be located in the same directory of 'write_questa_cdc_script.tcl' script."
  exit 1
endif

echo "source $rootdir/write_questa_cdc_script.tcl" >> $setup_file
if ( $remove == 0 ) then
  echo "write_questa_cdc_script -add_button"  >> $setup_file
else
  echo "write_questa_cdc_script -remove_button"  >> $setup_file
endif
echo "exit" >> $setup_file

vivado -mode tcl -source $setup_file
rm -f $setup_file
