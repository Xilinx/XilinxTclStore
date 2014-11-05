# this script allows to generate unique id numbers for printed messages

set processDir ".." ;# path to directory where we look for scripts with messages
set backupFiles 0 ;# backup or not modified files

set counter 1
foreach file [glob -nocomplain -directory $processDir -type {f r w} *.tcl] {
  set oldFile ${file}.backup
  file rename -force $file $oldFile
  
  set out [open $file w]
  set in [open $oldFile r]

  while { ![eof $in] } {
    gets $in line

    if { [regsub {send_msg_id\s+[^\s]+\s+} $line "send_msg_id USF-\[getSimulatorName\]-$counter " line] } {
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