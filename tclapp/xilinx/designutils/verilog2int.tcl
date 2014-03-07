package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export verilog2int
}

proc ::tclapp::xilinx::designutils::verilog2int { number } {
  # Summary :  Convert a Verilog formatted number into an integer
  
  # Argument Usage:
  # number : Verilog format number to convert

  # Return Value:
  # converted integer
  
  # Categories: xilinxtclstore, designutils
  
  set COMMENT_var_re {
      re matches <sign><num bits><base><number> where:
      sign is missing or '-'
      num bits is number of bits for the number (currently unchecked)
      base is h,d,o,b (hex, decimal, octal, binary -- case insensitive)
      number is the digits to be converted

  }
  set re {^(-?)(\d*)'([[:alpha:]])([[:xdigit:]]+)$}

  if [regex -nocase $re [string trim $number] - sign numbits base num] {
    set val [switch [string tolower $base] {
        b { expr 0b$num }
        o { expr 0$num }
        h { expr 0x$num }
        d { expr $num }
        default { error "Bad conversion base: $base" }
    }
            ]

    return $sign$val
  }
  return $number
}

