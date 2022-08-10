//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : uart_rx_ctl.v
//  Parent   : uart_rx
//  Children : none
//
//  Description: 
//     UART receiver controller
//     Implements the state machines for doing RS232 reception.
//
//     Based on the detection of the falling edge of the synchronized rxd
//     input, this module waits 1/2 of a bit period (8 periods of baud_x16_en)
//     to find the middle of the start bit, and resamples it. If rxd 
//     is still low it accepts it as a valid START bit, and captures the rest
//     of the character, otherwise it rejects the start bit and returns to
//     idle.
//
//     After detecting the START bit, it advances 1 full bit period at a time
//     (16 periods of baud_x16_en) to end up in the middle of the 8 data
//     bits, where it samples the 8 data bits. 
//
//     After the last bit is sampled (the MSbit, since the LSbit is sent
//     first), it waits one additional bit period to check for the STOP bit.
//     If the rxd line is not high (the value of a STOP bit), a framing error
//     is signalled. Regardless of the value of the rxd, though, the module
//     returns to the IDLE state and immediately begins looking for the 
//     start of the next character.
//
//     NOTE: The total cycle time through the state machine is 9 1/2 bit
//     periods (not 10) - this allows for a mismatch between the transmit and
//     receive clock rates by as much as 5%.
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


module uart_rx_ctl (
  // Write side inputs
  input            clk_rx,       // Clock input
  input            rst_clk_rx,   // Active HIGH reset - synchronous to clk_rx
  input            baud_x16_en,  // 16x oversampling enable

  input            rxd_clk_rx,   // RS232 RXD pin - after sync to clk_rx

  output reg [7:0] rx_data,      // 8 bit data output
                                 //  - valid when rx_data_rdy is asserted
  output reg       rx_data_rdy,  // Ready signal for rx_data
  output reg       frm_err       // The STOP bit was not detected
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

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire         over_sample_cnt_done; // We are in the middle of a bit
  wire         bit_cnt_done;         // This is the last data bit
  
//***************************************************************************
// Code
//***************************************************************************

  // Main state machine
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      state       <= IDLE;
    end
    else
    begin
      if (baud_x16_en) 
      begin
        case (state)
          IDLE: begin
            // On detection of rxd_clk_rx being low, transition to the START
            // state
            if (!rxd_clk_rx)
            begin
              state <= START;
            end
          end // IDLE state

          START: begin
            // After 1/2 bit period, re-confirm the start state
            if (over_sample_cnt_done)
            begin
              if (!rxd_clk_rx)
              begin
                // Was a legitimate start bit (not a glitch)
                state <= DATA;
              end
              else
              begin
                // Was a glitch - reject
                state <= IDLE;
              end
            end // if over_sample_cnt_done
          end // START state

          DATA: begin
            // Once the last bit has been received, check for the stop bit
            if (over_sample_cnt_done && bit_cnt_done)
            begin
              state <= STOP;
            end
          end // DATA state

          STOP: begin
            // Return to idle
            if (over_sample_cnt_done)
            begin
              state <= IDLE;
            end
          end // STOP state
        endcase
      end // if baud_x16_en
    end // if rst_clk_rx
  end // always 


  // Oversample counter
  // Pre-load to 7 when a start condition is detected (rxd_clk_rx is 0 while in
  // IDLE) - this will get us to the middle of the first bit.
  // Pre-load to 15 after the START is confirmed and between all data bits.
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
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
          if ((state == IDLE) && !rxd_clk_rx)
          begin
            over_sample_cnt <= 4'd7;
          end
          else if ( ((state == START) && !rxd_clk_rx) || (state == DATA)  )
          begin
            over_sample_cnt <= 4'd15;
          end
        end
      end // if baud_x16_en
    end // if rst_clk_rx
  end // always 

  assign over_sample_cnt_done = (over_sample_cnt == 4'd0);

  // Track which bit we are about to receive
  // Set to 0 when we confirm the start condition
  // Increment in all DATA states
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
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
    end // if rst_clk_rx
  end // always 

  assign bit_cnt_done = (bit_cnt == 3'd7);

  // Capture the data and generate the rdy signal
  // The rdy signal will be generated as soon as the last bit of data
  // is captured - even though the STOP bit hasn't been confirmed. It will
  // remain asserted for one BIT period (16 baud_x16_en periods)
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      rx_data     <= 8'b0000_0000;
      rx_data_rdy <= 1'b0;
    end
    else
    begin
      if (baud_x16_en && over_sample_cnt_done) 
      begin
        if (state == DATA)
        begin
          rx_data[bit_cnt] <= rxd_clk_rx;
          rx_data_rdy      <= (bit_cnt == 3'd7);
        end
        else
        begin
          rx_data_rdy      <= 1'b0;
        end
      end
    end // if rst_clk_rx
  end // always 

  // Framing error generation
  // Generate for one baud_x16_en period as soon as the framing bit
  // is supposed to be sampled
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      frm_err     <= 1'b0;
    end
    else
    begin
      if (baud_x16_en) 
      begin
        if ((state == STOP) && over_sample_cnt_done && !rxd_clk_rx)
        begin
          frm_err <= 1'b1;
        end
        else
        begin
          frm_err <= 1'b0;
        end
      end // if baud_x16_en
    end // if rst_clk_rx
  end // always 


endmodule
