# Extend the auto_path to make mentor apps available
if {[lsearch -exact $::auto_path $dir] == -1} {
    lappend ::auto_path $dir
}
