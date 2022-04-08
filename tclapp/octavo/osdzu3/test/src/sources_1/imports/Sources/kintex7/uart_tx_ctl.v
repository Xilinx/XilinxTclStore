//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : uart_tx_ctl.v
//  Parent   : uart_tx
//  Children : none
//
//  Description: 
//     UART transmit controller
//     Implements the state machines for doing RS232 transmission.
//
//     Whenever a character is ready for transmission (as indicated by the
//     empty signal from the character FIFO), this module will transmit the
//     character.
//
//     The basis of this design is a simple state machine. When in IDLE, it
//     waits for the character FIFO to indicate that a character is available,
//     at which time, it immediately starts transmition. It spends 16
//     baud_x16_en periods in the START state, transmitting the START
//     condition (1'b0), then tranisitions to the DATA state, where it sends
//     the 8 data bits (LSbit first), each lasting 16 baud_x16_en periods, and
//     finally going to the STOP state for 16 periods, where it transmits the
//     STOP value (1'b1).
//
//     On the last baud_x16_en period of the last data bit (in the DATA
//     state), it issues the POP signal to the character FIFO. Since the SM is
//     only enabled when baud_x16_en is asserted, the resulting pop signal
//     must then be ANDed with baud_x16_en to ensure that only one character
//     is popped at a time. 
//
//     On the last baud_x16_en period of the STOP state, the empty indication
//     from the character FIFO is inspected; if asserted, the SM returns to
//     the IDLE state, otherwise it transitions directly to the START state to
//     start the transmission of the next character.
//
//     There are two internal counters - one which counts off the 16 pulses of
//     baud_x16_en, and a second which counts the 8 bits of data.
//
//     The generation of the output (txd_tx) follows one complete baud_x16_en
//     period after the state machine and other internal counters.
//
//  Parameters:
//     None
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//    All flip-flops within this module share the same chip enable, generated
//    by the Baud rate generator. Hence, all paths from FFs to FFs in this
//    module are multicycle paths.
//

`timescale 1ns/1ps


module uart_tx_ctl (
  input            clk_tx,          // Clock input
  input            rst_clk_tx,      // Active HIGH reset - synchronous to clk_tx

  input            baud_x16_en,     // 16x bit oversampling pulse

  input            char_fifo_empty, // Empty signal from char FIFO (FWFT)
  input      [7:0] char_fifo_dout,  // Data from the char FIFO
  output           char_fifo_rd_en, // Pop signal to the char FIFO

  output reg       txd_tx           // The transmit serial signal
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  // State encoding for main FSM
  localparam 
    IDLE  = 2'b00,
    START = 2'b01,
    DATA  = 2'b10,
    STOP  = 2'b11;


//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [1:0]    state;             // Main state machine
  reg [3:0]    over_sample_cnt;   // Oversample counter - 16 per bit
  reg [2:0]    bit_cnt;           // Bit counter - which bit are we RXing
  reg          char_fifo_pop;     // POP indication to FIFO
                                  // ANDed with baud_x16_en before module
                                  // output

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire         over_sample_cnt_done; // We are in the middle of a bit
  wire         bit_cnt_done;         // This is the last data bit
  
//***************************************************************************
// Code
//***************************************************************************

  // Main state machine
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      state         <= IDLE;
      char_fifo_pop <= 1'b0;
    end
    else
    begin
      if (baud_x16_en) 
      begin
        char_fifo_pop <= 1'b0;
        case (state)
          IDLE: begin
            // When the character FIFO is not empty, transition to the START
            // state
            if (!char_fifo_empty)
            begin
              state <= START;
            end
          end // IDLE state

          START: begin
            if (over_sample_cnt_done)
            begin
              state <= DATA;
            end // if over_sample_cnt_done
          end // START state

          DATA: begin
            // Once the last bit has been transmitted, send the stop bit
            // Also, we need to POP the FIFO 
            if (over_sample_cnt_done && bit_cnt_done)
            begin
              char_fifo_pop <= 1'b1;
              state         <= STOP;
            end
          end // DATA state

          STOP: begin
            if (over_sample_cnt_done)
            begin
              // If there is no new character to start, return to IDLE, else
              // start it right away
              if (char_fifo_empty)
              begin
                state <= IDLE;
              end
              else
              begin
                state <= START;
              end
            end
          end // STOP state
        endcase
      end // if baud_x16_en
    end // if rst_clk_tx
  end // always 

  // Assert the rd_en to the FIFO for only ONE clock period
  assign char_fifo_rd_en = char_fifo_pop && baud_x16_en;


  // Oversample counter
  // Pre-load whenever we are starting a new character (in IDLE or in STOP),
  // or whenever we are within a character (when we are in START or DATA).
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      over_sample_cnt    <= 4'd0;
    end
    else
    begin
      if (baud_x16_en) 
      begin
        if (!over_sample_cnt_done)
        begin
          over_sample_cnt <= over_sample_cnt - 1'b1;
        end
        else
        begin
          if (((state == IDLE) && !char_fifo_empty) ||
              (state == START) || 
              (state == DATA)  ||
              ((state == STOP) && !char_fifo_empty))
          begin
            over_sample_cnt <= 4'd15;
          end
        end
      end // if baud_x16_en
    end // if rst_clk_tx
  end // always 

  assign over_sample_cnt_done = (over_sample_cnt == 4'd0);

  // Track which bit we are about to transmit
  // Set to 0 in the START state 
  // Increment in all DATA states
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      bit_cnt    <= 3'b0;
    end
    else
    begin
      if (baud_x16_en) 
      begin
        if (over_sample_cnt_done)
        begin
          if (state == START)
          begin
            bit_cnt <= 3'd0;
          end
          else if (state == DATA)
          begin
            bit_cnt <= bit_cnt + 1'b1;
          end
        end // if over_sample_cnt_done
      end // if baud_x16_en
    end // if rst_clk_tx
  end // always 

  assign bit_cnt_done = (bit_cnt == 3'd7);

  // Generate the output
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      txd_tx    <= 1'b1;
    end
    else
    begin
      if (baud_x16_en)
      begin
        if ((state == STOP) || (state == IDLE))
        begin
          txd_tx <= 1'b1;
        end
        else if (state == START)
        begin
          txd_tx <= 1'b0;
        end
        else // we are in DATA
        begin
          txd_tx <= char_fifo_dout[bit_cnt];
        end
      end // if baud_x16_en
    end // if rst
  end // always

endmodule
