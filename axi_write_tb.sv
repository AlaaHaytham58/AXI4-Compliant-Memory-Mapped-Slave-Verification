`include "axi_constraints.sv"
`timescale 1ns/1ps

module axi4_tb #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16, MEMORY_DEPTH = 1024)
(arb_if.TEST arbif_write);  // Interface passed via port

  import axi_enum::*;

  axi_packet write;
  bit [1:0] golden_bresp;
  bit [1:0] captured_bresp;

  // ====================
  // TEST SEQUENCE
  // ====================
  initial begin
    repeat(100) begin
      write = new();
      generate_stimulus(write);
      drive_write(write);
      collect_response(captured_bresp);
      golden_model(write, golden_bresp);
      check_response(captured_bresp, golden_bresp);
    end 
    $finish;    
  end

  // ====================
  // STIMULUS GENERATION
  // ====================
  function automatic void generate_stimulus(ref axi_packet pkt);
    assert(pkt.randomize()) else begin
      $display("Randomization failed");
      $stop;
    end
  endfunction

  // ====================
  // WRITE DRIVER
  // ====================
  task automatic drive_write(ref axi_packet pkt);
    if (pkt.axi_access == ACCESS_WRITE) begin
      arbif_write.AWLEN   = pkt.awlen;
      arbif_write.AWSIZE  = pkt.awsize;
      arbif_write.BREADY  = 1;

      // Address generation
      if (pkt.inlimit == INLIMIT)
        arbif_write.AWADDR = pkt.awaddr;
      else
        arbif_write.AWADDR = $urandom_range(MEMORY_DEPTH * 4, 2**ADDR_WIDTH - 1);

      @(negedge arbif_write.ACLK);
      arbif_write.AWVALID = 1;
      wait (arbif_write.AWREADY);
      @(negedge arbif_write.ACLK);
      arbif_write.AWVALID = 0;

      // Burst write data
      for (int i = 0; i <= pkt.awlen; i++) begin
        @(negedge arbif_write.ACLK);
        arbif_write.WDATA  = pkt.burst_data[i];
        arbif_write.WVALID = 1;
        arbif_write.WLAST  = (i == pkt.awlen);
        wait (arbif_write.WREADY);
      end

      // Clear signals
      @(negedge arbif_write.ACLK);
      arbif_write.WVALID = 0;
      arbif_write.WLAST  = 0;
      arbif_write.WDATA  = 0;
    end
  endtask

  // ====================
  // RESPONSE COLLECTION
  // ====================
  task automatic collect_response(output bit [1:0] bresp);
    wait (arbif_write.BVALID);
    bresp = arbif_write.BRESP;
    @(negedge arbif_write.ACLK);
    arbif_write.BREADY = 0;
  endtask

  // ====================
  // GOLDEN MODEL
  // ====================
  function automatic void golden_model(ref axi_packet pkt, output bit [1:0] bresp);
    if (pkt.axi_access == ACCESS_WRITE) begin
      if (pkt.inlimit == INLIMIT)
        bresp = 2'b00; // OKAY
      else
        bresp = 2'b10; // SLVERR
    end
  endfunction

  // ====================
  // CHECK RESPONSE
  // ====================
  task automatic check_response(bit [1:0] actual, expected);
    if (actual !== expected) begin
      $error("BRESP mismatch: expected=%b, got=%b", expected, actual);
    end else begin
      $display("Write successful: BRESP=%b as expected", actual);
    end
  endtask

endmodule
