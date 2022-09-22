//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : cmd_parse.v
//  Parent   : wave_gen.v
//  Children : None
//
//  Description: 
//     This module parses the incoming character stream looking for commands.
//     Characters are ignored when the char_fifo indicates that it is full.
//     
//     This module also manages the sample RAM and maintains the 3 variables, 
//     nsamp, prescale and speed.
//
//  Parameters:
//     PW: Width of pulse required for clock crossing to the clk_tx domain
//         should be set to 3
//     NSAMP_MIN: Minimum allowable value for NSAMP - should be set to 1
//     NSAMP_MAX: Maximum allowable value for NSAMP - should be set to 1024
//     PRESCALE_MIN: Minumum allowable value for prescale - should be 32
//                   to correspond to the DAC SPI cycle
//
//  Local Parameters:
//     RESP_TYPE_*: Values for the different response types
//
//  Notes       : 
//
//  Multicycle and False Paths
//     None
//

`timescale 1ns/1ps


module cmd_parse #(
  parameter   NSAMP_WID    = 10,    // Number of bits in RAM address
  parameter   PW           = 3      // Pulse width for clock crossing
) (
  input             clk_rx,         // Clock input
  input             rst_clk_rx,     // Active HIGH reset - synchronous to clk_rx

  input      [7:0]  rx_data,        // Character to be parsed
  input             rx_data_rdy,    // Ready signal for rx_data

  // From Character FIFO
  input             char_fifo_full, // The char_fifo is full

  // To/From Response generator
  output reg        send_char_val,  // A character is ready to be sent
  output reg [7:0]  send_char,      // Character to be sent

  output reg        send_resp_val,  // A response is requested
  output reg [1:0]  send_resp_type, // Type of response - see localparams
  output reg [15:0] send_resp_data, // Data to be output

  input             send_resp_done, // The response generation is complete

  // To Sample Generator
  output     [NSAMP_WID:0] 
                    nsamp_clk_rx,   // Current value of nsamp
  output            nsamp_new_clk_rx, // A new nsamp is available
  
  output     [15:0] pre_clk_rx,     // Current value of prescale
  output            pre_new_clk_rx, // A new prescale is available

  output     [15:0] spd_clk_rx,     // Current value of speed
  output            spd_new_clk_rx, // A new speed is available

  output reg        samp_gen_go_clk_rx, // Enable for sample generator

  // To/From Sample RAM
  output reg [15:0] cmd_samp_ram_din, // Data to write to sample RAM
  output reg [NSAMP_WID-1:0]  
                    cmd_samp_ram_addr,// Address for sample RAM read or write
  output reg        cmd_samp_ram_we,  // Write enable to sample RAM
  input      [15:0] cmd_samp_ram_dout // Read data from sample RAM
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter 
     NSAMP_MIN    = 1,    // Minimum allowable value for nsamp
     NSAMP_MAX    = 2**NSAMP_WID, // Maximum allowable value for nsamp
     PRESCALE_MIN = 32,   // Minimum allowable value for prescale 
     SPEED_MIN    = 1,    // Minimum allowable value for speed
     RAM_MAX      = NSAMP_MAX - 1, // Last RAM location
     SAMP_WID     = 16,   // 16 bits per sample
     PRE_WID      = 16,   // Width of prescale
     SPD_WID      = 16,   // Width of speed
     MAX_ARG_CH   = 8;    // Number of characters in largest set of args

  localparam [1:0]
     RESP_OK   = 2'b00,
     RESP_ERR  = 2'b01,
     RESP_DATA = 2'b11;

  // States for the main state machine
  localparam
     IDLE      = 3'b000,
     CMD_WAIT  = 3'b001,
     GET_ARG   = 3'b010,
     READ_RAM  = 3'b011,
     READ_RAM2 = 3'b100,
     SEND_RESP = 3'b101;

   localparam
     CMD_W     = 7'h57,
     CMD_R     = 7'h52,
     CMD_N     = 7'h4e,
     CMD_P     = 7'h50,
     CMD_S     = 7'h53,
     CMD_n_l   = 7'h6e,
     CMD_p_l   = 7'h70,
     CMD_s_l   = 7'h73,
     CMD_G     = 7'h47,
     CMD_C     = 7'h43,
     CMD_H     = 7'h48;

//***************************************************************************
// Functions declarations
//***************************************************************************

  `include "clogb2.vh"


//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [2:0]         state;    // State variable

  reg               old_rx_data_rdy; // rx_data_rdy on previous clock

  reg [6:0]         cur_cmd;  // Current cmd - least 7 significant bits of char
  reg [4*MAX_ARG_CH-5:0]        arg_sav;  // All but last char of args 
  reg [clogb2(MAX_ARG_CH)-1:0]  arg_cnt;  // Count the #chars in an argument

  reg [NSAMP_WID:0] nsamp;    // Number of samples to send
                              // Width is one more to code 2*N naturally
  reg [PRE_WID-1:0] prescale; // Clock prescaler
  reg [SPD_WID-1:0] speed;    // Speed
  reg               nsamp_new;   
  reg               prescale_new;
  reg               speed_new;

  reg [clogb2(PW)-1:0]   samp_gen_go_ctr;  // Counts from PW-1 to 0
  reg                    samp_gen_go_cont; // State of continuous looping


//***************************************************************************
// Wire declarations
//***************************************************************************

  // Accept a new character when one is available, and we can push it into
  // the response FIFO. A new character is available on the FIRST clock that
  // rx_data_rdy is asserted - it remains asserted for 1/16th of a bit period.
  wire new_char = rx_data_rdy && !old_rx_data_rdy && !char_fifo_full; 

  
//***************************************************************************
// Tasks and Functions
//***************************************************************************

  // This function takes the lower 7 bits of a character and converts them
  // to a hex digit. It returns 5 bits - the upper bit is set if the character
  // is not a valid hex digit (i.e. is not 0-9,a-f, A-F), and the remaining
  // 4 bits are the digit
  function [4:0] to_val;
    input [6:0] char;
  begin
    if ((char >= 7'h30) && (char <= 7'h39)) // 0-9
    begin
      to_val[4]   = 1'b0;
      to_val[3:0] = char[3:0];
    end
    else if (((char >= 7'h41) && (char <= 7'h46)) || // A-F
             ((char >= 7'h61) && (char <= 7'h66)) )  // a-f
    begin
      to_val[4]   = 1'b0;
      to_val[3:0] = char[3:0] + 4'h9; // gives 10 - 15
    end
    else 
    begin
      to_val      = 5'b1_0000;
    end
  end
  endfunction

//***************************************************************************
// Code
//***************************************************************************

  // capture the rx_data_rdy for edge detection
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      old_rx_data_rdy <= 1'b0;
    end
    else
    begin
      old_rx_data_rdy <= rx_data_rdy;
    end
  end

  // Echo the incoming character to the output, if there is room in the FIFO
  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      send_char_val <= 1'b0;
      send_char     <= 8'h00;
    end
    else if (new_char)
    begin
      send_char_val <= 1'b1;
      send_char     <= rx_data;
    end // if !rst and new_char
    else
    begin
      send_char_val <= 1'b0;
    end
  end // always

  // For each character that is potentially part of an argument, we need to 
  // check that it is in the HEX range, and then figure out what the value is.
  // This is done using the function to_val
  wire [4:0]  char_to_digit = to_val(rx_data);

  wire        char_is_digit = !char_to_digit[4];

  // Assuming it is a value, the new digit is the least significant digit of
  // those that have already come in - thus we need to concatenate the new 4
  // bits to the right of the existing data
  wire [4*MAX_ARG_CH-1:0] arg_val       = {arg_sav,char_to_digit[3:0]};

  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      state             <= IDLE;
      cur_cmd           <= 7'h00;
      arg_sav           <= 28'b0;
      arg_cnt           <= 3'b0;
      send_resp_val     <= 1'b0;
      send_resp_type    <= RESP_ERR;
      send_resp_data    <= 16'h0000;
      cmd_samp_ram_we   <= 1'b0;
      cmd_samp_ram_addr <= 10'h000;
      cmd_samp_ram_din  <= 16'h0000;
      nsamp             <= 11'h001;   // Set to min legal value
      nsamp_new         <= 1'b0;
      speed             <= 16'h0001;  // Set to min legal value
      speed_new         <= 1'b0;
      prescale          <= 16'd0032;  // Set to min legal value
      prescale_new      <= 1'b0;
    end
    else
    begin
      // Defaults - overridden in the appropriate state
      cmd_samp_ram_we <= 1'b0;
      nsamp_new       <= 1'b0;
      speed_new       <= 1'b0;
      prescale_new    <= 1'b0;
      
      case (state)

        IDLE: begin // Wait for the '*'
          if (new_char && (rx_data[6:0] == 7'h2A))
          begin
            state <= CMD_WAIT;
          end // if found *
        end // state IDLE

        CMD_WAIT: begin // Validate the incoming command
          if (new_char)
          begin
            cur_cmd <= rx_data[7:0];
            case (rx_data[6:0])
  
              CMD_W: begin // W - write
                // Get 8 characters of arguments
                // First 4 are address 2nd 4 are data
                state   <= GET_ARG;
                arg_cnt <= 3'd7;
              end  // W
  
              CMD_R,       // R - read
              CMD_N,       // N - set nsamp
              CMD_P,       // P - set prescale
              CMD_S: begin // S - set speed
                // Get 4 characters of arguments
                state   <= GET_ARG;
                arg_cnt <= 3'd3;
              end  // R, N, P, or S
              
              CMD_n_l: begin // n - print nsamp
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_DATA;
                send_resp_data <= nsamp;
                state          <= SEND_RESP;
              end // n
                
              CMD_p_l: begin // p - print prescale
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_DATA;
                send_resp_data <= prescale;
                state          <= SEND_RESP;
              end // p
  
              CMD_s_l: begin // s - print nsamp
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_DATA;
                send_resp_data <= speed;
                state          <= SEND_RESP;
              end // s
  
              CMD_G,       // G - go
              CMD_C,       // C - continuous
              CMD_H: begin // H - halt
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_OK;
                state          <= SEND_RESP;
              end // G C H
  
              default: begin
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_ERR;
                state          <= SEND_RESP;
              end // default
            endcase // current character case
          end // if new character has arrived
        end // state CMD_WAIT
        
        GET_ARG: begin
          // Get the correct number of characters of argument. Check that
          // all characters are legel HEX values.
          // Once the last character is successfully received, take action
          // based on what the current command is
          if (new_char)
          begin
            if (!char_is_digit)
            begin
              // Send an error response
              send_resp_val  <= 1'b1;
              send_resp_type <= RESP_ERR;
              state          <= SEND_RESP;
            end
            else // character IS a digit
            begin
              if (arg_cnt != 3'b000) // This is NOT the last char of arg
              begin
                // append the current digit to the saved ones
                arg_sav <= arg_val;  
                // Wait for the next character
                arg_cnt <= arg_cnt - 1'b1;
              end // Not last char of arg
              else // This IS the last character of the argument - process
              begin
                case (cur_cmd) 
                  CMD_W: begin
                    // Initiate a write to the RAM if in range
                    //
                    // The first argument is the address - it needs to be
                    // less than 1024 for the write to be valid. Thus we
                    // need to check arg_val[31:16] - if its valid, then
                    // the bottom ten bits of this are the address, and 
                    // arg_val[15:0] is the data to write
                    if (arg_val[31:16] <= RAM_MAX) // Valid address
                    begin
                      // Write the RAM and send OK
                      cmd_samp_ram_we   <= 1'b1; // Write it to the RAM
                      cmd_samp_ram_addr <= arg_val[25:16]; 
                      cmd_samp_ram_din  <= arg_val[15:0];
                      send_resp_val     <= 1'b1;
                      send_resp_type    <= RESP_OK;
                      state             <= SEND_RESP;
                    end 
                    else // not valid address
                    begin
                      // Send ERR
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_ERR;
                      state          <= SEND_RESP;
                    end
                  end // CMD_W

                  CMD_R: begin
                    // Initiate a read from the RAM if in range
                    // The first (and only) arg is the read address (in 15:0)
                    if (arg_val[15:0] <= RAM_MAX) // Valid address
                    begin
                      // Initiate the read
                      cmd_samp_ram_addr <= arg_val[NSAMP_WID-1:0]; 
                      state             <= READ_RAM;
                    end 
                    else // not valid address
                    begin
                      // Send ERR
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_ERR;
                      state          <= SEND_RESP;
                    end
                  end // CMD_R

                  CMD_N: begin
                    // Update nsamp with the only arg, if in range
                    if ((arg_val[15:0]  >= NSAMP_MIN) &&
                        (arg_val[15:0] <= NSAMP_MAX) )// Valid range
                    begin
                      // Update nsamp
                      nsamp          <= arg_val[NSAMP_WID:0];
                      nsamp_new      <= 1'b1;
                      // Send OK
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_OK;
                      state          <= SEND_RESP;
                    end 
                    else // not in range
                    begin
                      // Send ERR
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_ERR;
                      state          <= SEND_RESP;
                    end
                  end // CMD_N

                  CMD_P: begin
                    // Update prescale with the only arg, if in range
                    if (arg_val[15:0]  >= PRESCALE_MIN) // In range
                    begin
                      // Update nsamp
                      prescale       <= arg_val[15:0];
                      prescale_new   <= 1'b1;
                      // Send OK
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_OK;
                      state          <= SEND_RESP;
                    end 
                    else // not valid range
                    begin
                      // Send ERR
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_ERR;
                      state          <= SEND_RESP;
                    end
                  end // CMD_P

                  CMD_S: begin
                    // Update speed with the only arg, if in range
                    if (arg_val[15:0]  >= SPEED_MIN) // In range
                    begin
                      // Update speed
                      speed          <= arg_val[15:0];
                      speed_new      <= 1'b1;
                      // Send OK
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_OK;
                      state          <= SEND_RESP;
                    end 
                    else // not valid range
                    begin
                      // Send ERR
                      send_resp_val  <= 1'b1;
                      send_resp_type <= RESP_ERR;
                      state          <= SEND_RESP;
                    end
                  end // CMD_P

                endcase
              end // received last char of arg
            end // if the char is a valid HEX digit
          end // if new_char
        end // state GET_ARG

        READ_RAM: begin
          // The read request to the RAM is being issued this cycle
          // We need to wait for the data to be ready...
          // There is nothing to do other than wait one clock
          state <= READ_RAM2;
        end // state READ_RAM

        READ_RAM2: begin
          // The read request from the RAM is done, and the data is on the
          // dout port of the RAM - initiate the response
          send_resp_val  <= 1'b1;
          send_resp_type <= RESP_DATA;
          send_resp_data <= cmd_samp_ram_dout;
          state          <= SEND_RESP;
        end // state READ_RAM

        SEND_RESP: begin
          // The response request has already been sent - all we need to
          // do is keep the request asserted until the response is complete.
          // Once it is complete, we return to IDLE
          if (send_resp_done)
          begin
            send_resp_val <= 1'b0;
            state         <= IDLE;
          end
        end // state SEND_RESP

        default: begin
          state <= IDLE;
        end // state default

      endcase
    end // if !rst
  end // always


  assign nsamp_clk_rx     = nsamp;
  assign pre_clk_rx       = prescale;
  assign spd_clk_rx       = speed;
  assign nsamp_new_clk_rx = nsamp_new;
  assign pre_new_clk_rx   = prescale_new;
  assign spd_new_clk_rx   = speed_new;

  // Now handle the control to the Sample Generator
  // It has two functions
  //    - on receipt of a *G it asserts the output for PW clocks.
  //    - on receipt of a *C it asserts the output continuously.
  //    - on receipt of a *H it deasserts the output

  // To assert for PW clocks, we use the one where the *G is detected
  // and the PW-1 following clocks. To do that, we count from PW-1 to 0, and
  // keep the output asserted whenever the counter is not 0
  wire found_go = (state == CMD_WAIT) && new_char && (rx_data[6:0] == CMD_G);

  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      samp_gen_go_ctr <= 0;
    end
    else if (samp_gen_go_ctr != 0) // If not zero, in a count, so decrement
    begin
      samp_gen_go_ctr <= samp_gen_go_ctr - 1'b1;
    end
    else if (found_go)
    begin
      samp_gen_go_ctr <= PW - 1'b1;
    end
  end // always

  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      samp_gen_go_cont <= 1'b0;
    end
    else 
    begin
      if ((state == CMD_WAIT) && new_char)
      begin
        if (rx_data[6:0] == CMD_C)
          samp_gen_go_cont <= 1'b1;
        else if (rx_data[6:0] == CMD_H)
          samp_gen_go_cont <= 1'b0;
      end // Have a new character in CMD_WAIT
    end // !rst
  end // always

  always @(posedge clk_rx)
  begin
    if (rst_clk_rx)
    begin
      samp_gen_go_clk_rx <= 1'b0;
    end
    else 
    begin
      samp_gen_go_clk_rx <= found_go || 
                            (samp_gen_go_ctr != 0) || 
                            samp_gen_go_cont;
    end
  end

endmodule
