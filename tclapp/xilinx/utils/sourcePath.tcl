package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export sourcePath
}

proc ::tclapp::xilinx::utils::sourcePath {script auto_path} {
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
