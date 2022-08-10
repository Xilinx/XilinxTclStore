//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2009 Xilinx Inc.
//
//  Project  : Programmable Wave Generator
//  Module   : samp_gen.v
//  Parent   : wave_gen
//  Children : meta_harden
//
//  Description: 
//    This generates the output samples of the wave generator.
//
//    When enabled via the samp_gen_go_clk_rx signal, which is either pulsed
//    for 3 clocks or continuously asserted, it will cycle through all nsamp
//    samples at a rate of one sample every 'speed' cycles of the prescaled
//    clock (clk_samp), which is synchronous to clk_tx, but asserted only one
//    out of every 'prescale' cycles.
//
//    The samp_gen_go_clk_rx signal must be synchronized to clk_tx, and held
//    until the next rising edge of clk_samp (as indicated by the en_clk_samp)
//    signal.
//
//  Parameters:
//     NSAMP_WID:  Width of nsamp - since its coded naturally, must
//                 be one bit larger (to code 2**NSAMP_WID)
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//    Most of this module runs on clk_samp, which is a decimated clock. All
//    paths from FFs on clk_samp to FFs on clk_samp are multi-cycle. Since
//    prescale cannot be less than 32, these paths should all be declared as
//    32 cycle MCPs.
//
//    The metaharden module used within also requires a timing exception.
//

`timescale 1ns/1ps


module samp_gen #(
  parameter NSAMP_WID = 10
) (
  // Write side inputs
  input             clk_tx,       // Clock input
  input             rst_clk_tx,   // Active HIGH reset - synchronous to clk_tx
  input             clk_samp,     // Clock input
  input             rst_clk_samp, // Active HIGH reset - synchronous to clk_samp
  input             en_clk_samp,  // Last clk_tx phase of clk_samp
  input             samp_gen_go_clk_rx, // Starts the sample gen - on clk_rx
  input      [NSAMP_WID:0]
                    nsamp_clk_tx, // Current value of nsamp
  input      [15:0] spd_clk_tx,   // Current value of speed
  output     [NSAMP_WID-1:0] 
                    samp_gen_samp_ram_addr, // Address to sample RAM
  input      [15:0] samp_gen_samp_ram_dout, // Data returned from samp RAM
  output     [15:0] samp,         // Sample output
  output reg        samp_val,     // New sample is available
  output reg [7:0]  led_o         // Upper bits of samples sent to LEDs
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

//***************************************************************************
// Reg and Wire declarations
//***************************************************************************

  wire         samp_gen_go_clk_tx; // Meta_hardened
  reg          samp_gen_go_hold;   // Held until next clk_samp

  reg          active;             // Set when currently active

  reg [15:0]   speed_cnt;          // Counts speed-1 to 0
  reg [NSAMP_WID-1:0]   
               samp_cnt;           // Counts from 0 to nsamp-1

  wire         start_samp_gen;     // Signal that indicates the samp_gen shoud
                                   // start - a combination of the
                                   // synchronized samp_gen_go_clk_tx and
                                   // samp_gen_go_hold

  wire         restart_samp_gen;   // Indicates that we are completing one
                                   // sweep and need to immediately start
                                   // a new one

  wire         speed_cnt_done;     // The speed counter has reached 0
                                   // Time for next sample

  wire         samp_cnt_done;      // On the last sample

  reg          doing_read;         // The RAM is doing a read on this clock

  reg          read_done;          // This is the cycle that the read is done
                                   // Therefore the data is on the RAM output

  reg  [15:0]  samp_reg;           // Register for holding captured sample

  reg  [7:0]   led_clk_samp;       // LED signals on clk_samp
  reg  [7:0]   led_clk_tx;         // LED signals on clk_tx
  
//***************************************************************************
// Code
//***************************************************************************

  
  // Metastability harden samp_gen_go to the clk_tx domain
  meta_harden meta_harden_samp_gen_go_i0 (
    .clk_dst    (clk_tx),
    .rst_dst    (rst_clk_tx),
    .signal_src (samp_gen_go_clk_rx),
    .signal_dst (samp_gen_go_clk_tx)
  );

  // Capture and hold samp_gen_go
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      samp_gen_go_hold     <= #1 1'b0;
    end
    else
    begin
      if (samp_gen_go_hold)
      begin
        if (en_clk_samp && !samp_gen_go_clk_tx)
        begin
          samp_gen_go_hold <= #1 1'b0;
        end
      end
      else
      begin
        if (samp_gen_go_clk_tx && !en_clk_samp)
        begin
          samp_gen_go_hold <= #1 1'b1;
        end
      end
    end // if rst_clk_tx
  end // always 

  assign start_samp_gen = samp_gen_go_clk_tx || samp_gen_go_hold;

  assign restart_samp_gen = (speed_cnt_done && samp_cnt_done && start_samp_gen);

  // Track the current state of the sample generator. It is either active, or
  // inactive
  always @(posedge clk_samp)
  begin
    if (rst_clk_samp)
    begin
      active    <= 1'b0;
    end
    else
    begin
      if (!active)
      begin
        if (start_samp_gen)
        begin
          active <= 1'b1;
        end // Start while inactive
      end
      else // we are currently active
      begin
        // We go inactive if we are doing the last count, and we don't
        // need to restart
        if (samp_cnt_done && speed_cnt_done && !start_samp_gen)
        begin
          active <= 1'b0;
        end
      end
    end // if rst
  end // always

  // Generate speed_cnt. We are supposed to generate one sample every 
  // spd_clk_tx cycles, thus we need a counter. This counter counts form
  // spd_clk_tx-1 down to 0 for each sample. If spd_clk_tx is 1, then this
  // will count (correctly) from 0 to 0 (i.e. one iteration)
  always @(posedge clk_samp)
  begin
    if (rst_clk_samp)
    begin
      speed_cnt    <= 16'h0000;
    end
    else
    begin
      if (speed_cnt != 16'h0000)
      begin
        speed_cnt <= speed_cnt - 1'b1;
      end
      else if ((active && !samp_cnt_done) || start_samp_gen) 
      begin
        // speed_cnt is 0, so we have "completed" this sample...
        // Restart the counter to count the next sample, as long as there is
        // one.
        // There is a new sample if this is not the last sample. We also have
        // to restart if it IS the last sample, but we are being asked to
        // restart a new sweep right away (which will be the case in
        // "Continuous" mode *C.
        speed_cnt <= spd_clk_tx - 1'b1;
      end
    end // if rst_clk_samp
  end // always 

  assign speed_cnt_done = (speed_cnt == 16'h0000);

  // Track which sample we are sending - count from 0 to nsamp-1
  always @(posedge clk_samp)
  begin
    if (rst_clk_samp)
    begin
      samp_cnt    <= {NSAMP_WID{1'b0}};
    end
    else
    begin
      if ((!active && start_samp_gen) || restart_samp_gen) // Start a new sweep
      begin
        samp_cnt <= {NSAMP_WID{1'b0}}; // Start at 0
      end
      else if (active && speed_cnt_done && !samp_cnt_done)
      begin
        // speed_cnt is expiring, and this is not the last sample - get the 
        // next one. If this is the last one, and we are re-starting, we will
        // have loaded it via the condition above
        samp_cnt <= samp_cnt + 1'b1;
      end
    end // if rst_clk_samp
  end // always 

  assign samp_cnt_done = (samp_cnt == nsamp_clk_tx - 1'b1);

  assign samp_gen_samp_ram_addr = samp_cnt;

  // Generate doing_read - this is the clock where the address to the RAM is
  // valid, and hence the RAM will have the correct data on the next clock
  always @(posedge clk_samp)
  begin
    if (rst_clk_samp)
    begin
      doing_read  <= 1'b0;
    end
    else
    begin
      // This signal is asserted on the clock after samp_gen starts, 
      // or the clock after speed_cnt_done is asserted, unless this we
      // have already done the last sample, and we are not restarting.
      if ((!active && start_samp_gen) ||
          (active && speed_cnt_done && (!samp_cnt_done || restart_samp_gen) ) )
      begin
        doing_read <= 1'b1;
      end
      else
      begin
        doing_read <= 1'b0;
      end
    end // if rst_clk_samp
  end // always 

  // Generate the sample outputs
  always @(posedge clk_samp)
  begin
    if (rst_clk_samp)
    begin
      read_done    <= 1'b0;
      samp_reg     <= 1'b0;
      samp_val     <= 1'b0;
      led_clk_samp <= 8'b0;
    end
    else
    begin
      read_done    <= doing_read;
      samp_val     <= read_done;
      if (read_done)
      begin
        samp_reg   <= samp_gen_samp_ram_dout;
      end
      led_clk_samp <= samp_reg[15:8];
    end // if rst_clk_rx
  end // always 

  // Resynchronize the LED signals on clk_tx, which is a global
  // clock. The clock crossing between the two domains is synchronous.
  // Pipeline on clk_tx to allow for routing to pins across the chip
  always @(posedge clk_tx)
  begin
    if (rst_clk_tx)
    begin
      led_clk_tx <= 8'b0;
      led_o      <= 8'b0;
    end
    else
    begin
      led_clk_tx <= led_clk_samp;
      led_o      <= led_clk_tx;
    end
  end

  assign samp = samp_reg;


endmodule
