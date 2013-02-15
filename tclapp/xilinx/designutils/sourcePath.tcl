####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export sourcePath
}

proc ::tclapp::xilinx::designutils::sourcePath {script auto_path} {
    # Summary : source a script from a choice of paths

    # Argument Usage:
    # script : name of file to source
    # auto_path : list of directories

    # Return Value:
    # 1 on success
    # 0 if script could not be found
    
    foreach dir $auto_path {
        if {[file exists $dir/$script]} {
            source $dir/$script
            return 1
        }
    }
    puts "ERROR:  $script not found in $auto_path"
    return 0
}
