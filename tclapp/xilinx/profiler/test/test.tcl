set path [ file normalize [ file dirname [ info script ] ] ]
namespace eval profile_test {
  source [ file join $path profile_test.tcl ]
}
namespace eval unit_test {
  source [ file join $path unit_test.tcl ]
}
