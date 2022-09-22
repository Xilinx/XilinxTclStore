// Generate the ceiling of the log base 2 - i.e. the number of bits
// required to hold N different values - i.e. clogb2(N) will be large
// enough to hold the counts 0 to N-1
function integer clogb2;
  input [31:0] value;
  reg   [31:0] my_val;
  begin
    my_val = value - 1;
    for (clogb2 = 0; my_val > 0; clogb2 = clogb2 + 1)
      my_val = my_val >> 1;
  end
endfunction