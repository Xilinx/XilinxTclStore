# Extend the auto_path to make support code available
if {[lsearch -exact $::auto_path $dir] == -1} {
    lappend ::auto_path $dir
}
