`include "../Packages/axi_constraints.sv"

module axi4_tb #(
  parameter DATA_WIDTH = 32, 
  parameter ADDR_WIDTH = 16, 
  parameter MEMORY_DEPTH = 1024
) (
  arb_if arbif_pkt
);

import axi_enum_packet::*;
import axi_packet_all::*;

axi_packet #(ADDR_WIDTH, DATA_WIDTH, MEMORY_DEPTH) pkt;
bit [1:0] golden_resp;
bit [1:0] captured_resp;
bit [1:0] expected_rresp;
//bit [DATA_WIDTH-1:0] read_data_q[$];  

initial begin

  arbif_pkt.ARESETn = 0;
  @(negedge arbif_pkt.ACLK);
  arbif_pkt.ARESETn = 1;

  repeat (1000) begin
    pkt = new();
    generate_stimulus(pkt);

    if (pkt.axi_access == ACCESS_WRITE) begin
      drive_write(pkt);
      collect_response(captured_resp);
      golden_model(pkt, golden_resp);
      check_response(captured_resp, golden_resp);
   
    end else begin
      drive_read(pkt);
      collect_rdata(pkt);
      golden_model_read(pkt, expected_rresp);
    
    end
    pkt.cg.sample();
  end
  $stop;
end
//--------------------WRITE FUNCTIONALITY--------------------------
function automatic void generate_stimulus(ref axi_packet pkt);
  assert(pkt.randomize()) else begin
    $display("Randomization failed");
    $stop;
  end
  pkt.randarr();
endfunction

  task automatic drive_write(ref axi_packet write);
    if (write.axi_access == ACCESS_WRITE) begin
      arbif_pkt.AWLEN   = write.awlen;
      arbif_pkt.AWSIZE  = write.awsize;
      arbif_pkt.BREADY  = 1;

      $display("Write Started");
      if (write.inlimit == INLIMIT)
        arbif_pkt.AWADDR = write.awaddr;
      else
        arbif_pkt.AWADDR = $urandom_range(MEMORY_DEPTH * 4, 2**ADDR_WIDTH - 1);

      @(negedge arbif_pkt.ACLK);
      arbif_pkt.AWVALID = 1;

      $display("Waiting on AWREADY......");
      wait (arbif_pkt.AWREADY);

      @(negedge arbif_pkt.ACLK);
      arbif_pkt.AWVALID = 0;

      // Write data burst
      for (int i = 0; i <= write.awlen; i++) begin
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.WDATA  = write.data_array[i];
        arbif_pkt.WVALID = 1;
        arbif_pkt.WLAST  = (i == write.awlen) ? 1 : 0;
      
        $display("Waiting on WREADY......");
        wait (arbif_pkt.WREADY);
      end

      // Clear write signals
      @(negedge arbif_pkt.ACLK);
      arbif_pkt.WVALID = 0;
      arbif_pkt.WLAST  = 0;
      arbif_pkt.WDATA  = 0;
    end
  endtask

  task automatic collect_response(output bit [1:0] bresp);
    $display("Waiting on BVALID......");
    wait (arbif_pkt.BVALID);

    bresp = arbif_pkt.BRESP;
    @(negedge arbif_pkt.ACLK);
    arbif_pkt.BREADY = 0;
  endtask

  
  function automatic void golden_model(ref axi_packet write, output bit [1:0] bresp);
    if (write.axi_access == ACCESS_WRITE) begin
      if (write.inlimit == INLIMIT)
        bresp = 2'b00; 
      else
        bresp = 2'b10;
    end
  endfunction

  task automatic check_response(bit [1:0] actual, expected);
    if (actual !== expected) begin
      $error("BRESP mismatch: expected=%b, got=%b", expected, actual);
    end else begin
      $display("Write successful: BRESP=%b as expected", actual);
    end
  endtask
  //------------------READ FUNCTIONALITY---------------

task automatic drive_read(ref axi_packet pkt);
  if (pkt.axi_access == ACCESS_READ) begin

    @(negedge arbif_pkt.ACLK)
    arbif_pkt.ARLEN   = pkt.arlen;
    arbif_pkt.ARSIZE  = pkt.arsize;

    if (pkt.inlimit == INLIMIT)
      arbif_pkt.ARADDR = pkt.araddr;
    else
      arbif_pkt.ARADDR = 2'b10;

    $display("Read Started");

    @(negedge arbif_pkt.ACLK);
    arbif_pkt.ARVALID = 1;

    $display("Waiting on ARREADY......");
    while (~arbif_pkt.ARREADY)
    begin
      if (arbif_pkt.BVALID && arbif_pkt.RRESP == 2'b10) begin
        $error("SLVERR while reading");
        break;
      end
    end

    @(negedge arbif_pkt.ACLK);
    arbif_pkt.ARVALID = 0;
  end

endtask
task automatic collect_rdata(ref axi_packet pkt);
  for (int i = 0; i < pkt.arlen; i++) begin
    if (arbif_pkt.RRESP == 2'b10 && arbif_pkt.RVALID == 1'b0)
      begin
        $error("Addresses out of range, data not collected");
        break;
      end
    @(negedge arbif_pkt.ACLK);
    arbif_pkt.RREADY = 1;
    $display("Waiting on RVALID......");
    while (~arbif_pkt.RVALID)
    begin
      if (arbif_pkt.RRESP == 2'b10) begin
        $error("SLVERR while reading");
        break;
      end
      @(negedge arbif_pkt.ACLK);
    end

    $display("[READ] Beat %0d: Data = %h, RRESP = %b", 
              i, arbif_pkt.RDATA, arbif_pkt.RRESP);

    if (arbif_pkt.RLAST) begin
      $display("[READ] Last data beat received.");
    end

  end
  arbif_pkt.RREADY = 0;
  if (arbif_pkt.RRESP !== expected_rresp) begin
  $display("RRESP mismatch: expected %b, got %b", expected_rresp, arbif_pkt.RRESP);
end
endtask
function automatic void golden_model_read(ref axi_packet pkt, output bit [1:0] rresp_golden);
  int  start_addr = pkt.araddr;
  int  word_addr  = start_addr >> 2;
  int  num_beats  = pkt.arlen + 1;
  int  total_bytes = num_beats * (1 << pkt.arsize);
  


  bit boundary = ((start_addr % 4096) + total_bytes > 4096);
  bit out_of_range = ((word_addr + num_beats) > MEMORY_DEPTH);

  if (boundary || out_of_range) begin
    rresp_golden = 2'b10;  
  end else begin
    rresp_golden = 2'b00;  
  end
endfunction

endmodule
