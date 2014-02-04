module  mux2(din_0, din_1, sel, mux_out);
   
/******************************************************************************/
/* Input definitions                                                          */
/******************************************************************************/
input din_0;
input din_1;
input sel;

/******************************************************************************/
/* Output definitions                                                         */
/******************************************************************************/
output mux_out;

/******************************************************************************/
/* Register and Wire definitions                                              */
/******************************************************************************/
wire  mux_out;

assign mux_out = (sel) ? din_1 : din_0;

endmodule  /* end of mux2 */ // unmatched end(function|task|module|primitive|interface|package|class|clocking)

