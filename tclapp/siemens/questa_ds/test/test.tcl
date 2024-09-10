set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

# Start the unit tests
puts "Script is invoked from $test_dir"
puts "Running 'test1'"
if {[catch {source -notrace [file join $test_dir questa_cdc_tclapp_test.tcl]} errorstring]} {
  puts "Test 'test1' failed."
  catch { close_project }
}
close_project

puts "Running 'test2'"
if {[catch {source -notrace [file join $test_dir questa_cdc_tclapp_test_1.tcl]} errorstring]} {
  puts "Test 'test2' failed."
  catch { close_project }
}
close_project

return 0
