`include "axi_constraints.sv"
`timescale 1ns/1ps

module axi4_tb #(
  parameter DATA_WIDTH = 32, 
  parameter ADDR_WIDTH = 16, 
  parameter MEMORY_DEPTH = 1024
) (
  arb_if.TEST arbif_write 
);

  
  import axi_enum_packet::*;
  import axi_packet_all::*;

  axi_packet #(ADDR_WIDTH, DATA_WIDTH, MEMORY_DEPTH) write;
  bit [1:0] golden_bresp;
  bit [1:0] captured_bresp;

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

  
  function automatic void generate_stimulus(ref axi_packet write);
    assert(write.randomize()) else begin
      $display("Randomization failed");
      $stop;
    end
    write.randarr();  
  endfunction

 
  task automatic drive_write(ref axi_packet write);
    if (write.axi_access == ACCESS_WRITE) begin
      arbif_write.AWLEN   = write.awlen;
      arbif_write.AWSIZE  = write.awsize;
      arbif_write.BREADY  = 1;

      if (write.inlimit == INLIMIT)
        arbif_write.AWADDR = write.awaddr;
      else
        arbif_write.AWADDR = $urandom_range(MEMORY_DEPTH * 4, 2**ADDR_WIDTH - 1);

      @(negedge arbif_write.ACLK);
      arbif_write.AWVALID = 1;
      wait (arbif_write.AWREADY);
      @(negedge arbif_write.ACLK);
      arbif_write.AWVALID = 0;

      // Write data burst
      for (int i = 0; i <= write.awlen; i++) begin
        @(negedge arbif_write.ACLK);
        arbif_write.WDATA  = write.data_array[i];
        arbif_write.WVALID = 1;
        arbif_write.WLAST  = (i == write.awlen) ? 1 : 0;
        wait (arbif_write.WREADY);
      end

      // Clear write signals
      @(negedge arbif_write.ACLK);
      arbif_write.WVALID = 0;
      arbif_write.WLAST  = 0;
      arbif_write.WDATA  = 0;
    end
  endtask

  task automatic collect_response(output bit [1:0] bresp);
    wait (arbif_write.BVALID);
    bresp = arbif_write.BRESP;
    @(negedge arbif_write.ACLK);
    arbif_write.BREADY = 0;
  endtask

  
  function automatic void golden_model(ref axi_packet write, output bit [1:0] bresp);
    if (write.axi_access == ACCESS_WRITE) begin
      if (write.inlimit == INLIMIT)
        bresp = 2'b00; // RESP_OKAY
      else
        bresp = ($urandom_range(0, 1) == 0) ? 2'b10 : 2'b01; // RESP_SLVERR or RESP_EXOKAY
    end
  endfunction

  task automatic check_response(bit [1:0] actual, expected);
    if (actual !== expected) begin
      $error("BRESP mismatch: expected=%b, got=%b", expected, actual);
    end else begin
      $display("Write successful: BRESP=%b as expected", actual);
    end
  endtask

endmodule
