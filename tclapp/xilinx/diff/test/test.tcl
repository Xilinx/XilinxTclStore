set path [ file normalize [ file dirname [ info script ] ] ]
namespace eval design_test {
  source [ file join $path design_test.tcl ]
}
namespace eval unit_test {
  source [ file join $path unit_test.tcl ]
}
