set path [file dirname [info script]]
puts "script is invoked from $path"
source [file join $path wpt_test_0001.tcl]
source [file join $path wpt_test_0002.tcl]
source [file join $path esf_test_0001.tcl]
source [file join $path esf_test_0002.tcl]
source [file join $path ngc_test_0001.tcl]
source -notrace [file join $path cpr_test_0001.tcl]
source [file join $path create_rqs_run_test_0001.tcl]
# Don't run these--they take took long.
#source [file join $path ebs_test_0001.tcl]
#source [file join $path ebs_test_0002.tcl]
