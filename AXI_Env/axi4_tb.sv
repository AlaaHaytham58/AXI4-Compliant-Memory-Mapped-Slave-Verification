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

//Read output struct;
typedef struct 
{
    bit [DATA_WIDTH-1:0] data;
    bit  [1:0] resp;
    bit last ;
}read_out;

//data read from dut, expected data
read_out read_data[]; 
read_out expected_data[];  

//Number of cycles to wait_valid on a ready or valid signal
int wait_valid;

//Memory to map data
reg [DATA_WIDTH-1:0] test_mem [0:MEMORY_DEPTH-1];

initial begin
    foreach(test_mem[i])
      test_mem[i] = 0;
    
      arbif_pkt.ARESETn = 0;
      @(negedge arbif_pkt.ACLK);
      arbif_pkt.ARESETn = 1;

      repeat (500) begin
      pkt = new();

      generate_stimulus(pkt);
      if (pkt.axi_access == ACCESS_WRITE) begin
        drive_write(pkt);
        //Skip testcase if valid signal took too long to respond
        if (wait_valid <= 0)  begin
            $error("Couldn't Continue the test case, ARREADY took to long to respond");
            continue;
        end

        collect_response(captured_resp);
        golden_model_write(pkt, golden_resp);
        check_wdata(pkt);

      end else begin
        drive_read(pkt);
        //Skip testcase if valid signal took too long to respond
        if (wait_valid <= 0)  begin
            $error("Couldn't Continue the test case, ARREADY took to long to respond");
            continue;
        end

        collect_rdata(pkt);
        //Skip testcase if valid signal took too long to respond
        if (wait_valid <= 0)  begin
            $error("Couldn't Continue the test case, RVALID took to long to respond");
            continue;
        end

        golden_model_read(pkt, expected_rresp);
        read_compare();
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
        $display("Write Started");

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWLEN   = write.awlen;
        arbif_pkt.AWSIZE  = write.awsize;
        arbif_pkt.BREADY  = 1;
        arbif_pkt.AWADDR = write.awaddr;
        arbif_pkt.AWVALID = 1;
        
        $display("Waiting on AWREADY......");
        wait_valid = 500;

       while (~arbif_pkt.AWREADY) begin
          @(negedge arbif_pkt.ACLK);
        //Stop waiting if it took to long to respond
        if (!(--wait_valid)) begin
          $error("AWREADY took too long to be asserted");
          break;
        end  
       end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWVALID = 0;

        // Write data burst
        for (int i = 0; i <= write.awlen; i++) begin
            @(negedge arbif_pkt.ACLK);
            arbif_pkt.WDATA  = write.data_array[i];
            arbif_pkt.WVALID = 1;
            arbif_pkt.WLAST  = (i == write.awlen) ? 1 : 0;
          
            $display("Waiting on WREADY......");
            while (~arbif_pkt.WREADY) begin
            @(negedge arbif_pkt.ACLK);
            //Stop waiting if it took to long to respond
            if (!(--wait_valid)) begin
              $error("WREADY took too long to be asserted");
            break;
            end  
          end
        end

        // Clear write signals
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.WVALID = 0;
        arbif_pkt.WLAST  = 0;
        arbif_pkt.WDATA  = 0;
    endtask

    task automatic collect_response(output bit [1:0] bresp);
      $display("Waiting on BVALID......");
      wait_valid = 500;
      while (arbif_pkt.BVALID) begin
        @(negedge arbif_pkt.ACLK);
        //Stop waiting if it took to long to respond
        if (!(--wait_valid)) begin
          $error("BVALID took too long to be asserted");
          break;
        end  
      end

      bresp = arbif_pkt.BRESP;

      @(negedge arbif_pkt.ACLK);
      arbif_pkt.BREADY = 0;
    endtask

    
    task automatic golden_model_write(ref axi_packet write, output bit [1:0] bresp);
      
        if (write.inlimit == INLIMIT) begin
          bresp = 2'b00; 
          for (int i = 0; i <= write.awlen; i++) 
          begin
            test_mem[(i*4 + arbif_pkt.AWADDR) >> 2] = pkt.data_array[i];
          end
        end
        else
          bresp = 2'b10;

    endtask

  task automatic check_wdata(ref axi_packet pkt);
      $display("Reading from memory to make sure data is added correctly...");

       pkt.arlen = pkt.awlen;
       pkt.arsize = pkt.awsize;
       pkt.araddr = pkt.awaddr;
      drive_read(pkt);
      //Skip testcase if valid signal took too long to respond
      if (wait_valid <= 0)  begin
          $error("Couldn't Continue the test case, ARREADY took to long to respond");
          return;
      end

      collect_rdata(pkt);
      //Skip testcase if valid signal took too long to respond
      if (wait_valid <= 0)  begin
          $error("Couldn't Continue the test case, RVALID took to long to respond");
          return;
      end

      golden_model_read(pkt, expected_rresp);
      read_compare();

      // if (actual !== expected) begin
      //   $error("BRESP mismatch: expected=%b, got=%b", expected, actual);
      // end else begin
      //   $display("Write successful: BRESP=%b as expected", actual);
      // end
  endtask

//------------------READ FUNCTIONALITY---------------

task automatic drive_read(ref axi_packet pkt);
begin
    $display("Read Started");
    //assert address (ARADDR), burst length (ARLEN), and size (ARSIZE) along with ARVALID.
    @(negedge arbif_pkt.ACLK)
    arbif_pkt.ARLEN   = pkt.arlen;
    arbif_pkt.ARSIZE  = pkt.arsize;
    arbif_pkt.ARADDR = pkt.araddr;
    arbif_pkt.ARVALID = 1;

    //waiting on ARREADY
    $display("Waiting on ARREADY......");
    wait_valid = 500;
    while (~arbif_pkt.ARREADY)
    begin
       @(negedge arbif_pkt.ACLK);
       //Stop waiting if it took to long to respond
       if (!(--wait_valid)) begin
        $error("ARREADY took too long to be asserted");
        break;
        end
    end

    //Set ARVALID to 0 after 1 cycle
    @(negedge arbif_pkt.ACLK);
    arbif_pkt.ARVALID = 0;
end
endtask

task automatic collect_rdata(ref axi_packet pkt);

    read_data = new[pkt.arlen + 1];

    for (int i = 0; i <= arbif_pkt.ARLEN; i++) begin
        //Set RREADY
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.RREADY = 1;

        //wait_valid for valid signal
        $display("Waiting on RVALID......");
        wait_valid = 500;

        while (~arbif_pkt.RVALID)
        begin
            @(negedge arbif_pkt.ACLK);
            //Stop waiting if it took too long to respond  
            if ((wait_valid) <= 0) begin
                $error("RVALID took too long to be asserted");
                break;
            end
            wait_valid--;
        end

        //Break out of the loop if it took too long to respond  
        if ((wait_valid) <= 0) begin
            $error("RVALID not asserted");
            break;
        end

        //collecting DUT output per beat
        read_data[i].data = arbif_pkt.RDATA;
        read_data[i].resp = arbif_pkt.RRESP;
        read_data[i].last = arbif_pkt.RLAST;

        $display("[READ] Beat %0d: Data = %h, RRESP = %b", 
                i, arbif_pkt.RDATA, arbif_pkt.RRESP);

        //Detect if RLAST is asserted
        if (arbif_pkt.RLAST) begin
          $display("[READ] Last data beat received.");
          break;
        end
    end
    
    //Turn off RREADY after one cycle of the last burst
    @(negedge arbif_pkt.ACLK)
    arbif_pkt.RREADY = 0;

    // if (arbif_pkt.RRESP !== expected_rresp) begin
    // $display("RRESP mismatch: expected %b, got %b", expected_rresp, arbif_pkt.RRESP);
    // end
endtask

function automatic void golden_model_read(ref axi_packet pkt, output bit [1:0] rresp_golden);
  int  start_addr = pkt.araddr;
  int  word_addr  = start_addr >> 2;
  int  num_beats  = pkt.arlen + 1;
  int  total_bytes = num_beats * (1 << pkt.arsize);
  


  bit boundary = ((start_addr % 4096) + total_bytes > 4096);
  bit out_of_range = ((word_addr + num_beats) > MEMORY_DEPTH);

  for (int i = 0; i <= arbif_pkt.ARLEN; i++) begin
      if (word_addr > MEMORY_DEPTH || ((start_addr + i*4 % 4096) + total_bytes > 4096))
      begin
        expected_data[i].data = 0;
        expected_data[i].resp = 2'b10;
        expected_data[i].last = 1;
        break;
      end
      else
      begin
        expected_data[i].data = test_mem[(start_addr + i*4) >> 2];
        expected_data[i].resp = 2'b00;
        expected_data[i].last = (i == pkt.arlen);
      end
  end
endfunction

function read_compare();
  for (int i = 0; i <= arbif_pkt.ARLEN; i++) begin
    if (expected_data[i].data == read_data[i].data && expected_data[i].resp == read_data[i].resp && expected_data[i].last == read_data[i].last)
      $display("read sucessful, data: %h, response: %b, last: %b",read_data[i].data,read_data[i].resp,read_data[i].last);
    else
      $display("read failed, data: %h, response: %b, last: %b",read_data[i].data,read_data[i].resp,read_data[i].last);

  end
endfunction
endmodule