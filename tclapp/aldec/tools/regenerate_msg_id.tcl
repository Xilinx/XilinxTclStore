# this script allows to generate unique id numbers for printed messages

set processDir ".." ;# path to directory where we look for scripts with messages
set backupFiles 0 ;# backup or not modified files

set counter 1

foreach dir [glob -nocomplain -directory $processDir -type {d} *] {
  foreach file [glob -nocomplain -directory $dir -type {f r w} *.tcl] {
    if { [file tail $file] == "regenerate_msg_id.tcl" } {
      continue
    }
  
    set oldFile ${file}.backup
    file rename -force $file $oldFile
    
    set out [open $file w]
    set in [open $oldFile r]

    while { ![eof $in] } {
      gets $in line

    if { [regsub {(send_msg_id\s+[^\s]+-)[0-9]+\s+} $line "\\1$counter " line] } {
      incr counter
    }    
      
      if { ![eof $in] || [string length $line] > 0 } {
        puts $out $line
      }    
    }  
    
    close $out
    close $in
    
    if { !$backupFiles } {
      file delete -force $oldFile
    }
  }
}
