####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export verilog2int
}

proc ::tclapp::xilinx::designutils::verilog2int { orig } {
  # Summary :  convert a Verilog format number to an integer
  
  # Argument Usage:
  # orig : verilog format number to convert

  # Return Value:
  # converted integer
  
  set COMMENT_var_re {
      re matches <sign><num bits><base><number> where:
      sign is missing or '-'
      num bits is number of bits for the number (currently unchecked)
      base is h,d,o,b (hex, decimal, octal, binary -- case insensitive)
      number is the digits to be converted

  }
  set re {^(-?)(\d*)'([[:alpha:]])([[:xdigit:]]+)$}

  if [regex -nocase $re [string trim $orig] - sign numbits base num] {
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
  return $orig
}

