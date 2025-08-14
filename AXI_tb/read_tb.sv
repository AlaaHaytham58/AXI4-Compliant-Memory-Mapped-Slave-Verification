`include "../Packages/axi_constraints.sv"

module read_tb #(
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
bit [DATA_WIDTH-1:0] read_data [15];  

int wait = 500;
//Memory to map data
reg [DATA_WIDTH-1:0] test_mem [0:MEMORY_DEPTH-1];

initial begin

  arbif_pkt.ARESETn = 0;
  @(negedge arbif_pkt.ACLK);
  arbif_pkt.ARESETn = 1;

  repeat (500) begin

    pkt = new();
    drive_read(pkt);

    if (captured_resp == 2'b10) begin
        $error("Couldn't Continue the test case due to SLVERR while reading address");
        continue;
    end
    
    collect_rdata(pkt);
    if (wait <= 0)  begin
        $error("Couldn't Continue the test case, RVALID took to long to respond");
        continue;
    end

    golden_model_read(pkt, expected_rresp);
    pkt.cg.sample();
  end
  $stop;
end
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
    wait = 500;
    while (~arbif_pkt.ARREADY)
    begin
      //Stop waiting if there is an error
      @(negedge arbif_pkt.ACLK);
      if (arbif_pkt.RRESP == 2'b10) begin
        $error("SLVERR in address reading phase");
        break;
      end

       //Stop waiting if it took to long to respond
       if (~(--wait)) begin
        $error("ARREADY took too long to be asserted");
        break;
        end
    end

    captured_resp = arbif_pkt.RRESP;

    //Set ARVALID to 0 after 1 cycle
    @(negedge arbif_pkt.ACLK);
    arbif_pkt.ARVALID = 0;
  end

endtask


task automatic collect_rdata(ref axi_packet pkt);

    for (int i = 0; i <= pkt.ARLEN; i++) begin
        //Set RREADY
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.RREADY = 1;

        //Wait for valid signal
        $display("Waiting on RVALID......");
        wait = 500;

        while (~arbif_pkt.RVALID)
        begin
            @(negedge arbif_pkt.ACLK);

            //Stop waiting if there is an error
            if (arbif_pkt.RRESP == 2'b10) begin
                $error("SLVERR while reading");
                break;
            end
            
            //Stop waiting if it took too long to respond  
            if (~(--wait)) begin
                $error("RVALID took too long to be asserted");
                break;
            end
        end

        //Break out of the loop if there is an error
        if (arbif_pkt.RRESP == 2'b10) begin
            $error("SLVERR while reading");
            break;
        end
        //Break out of the loop if it took too long to respond  
        if (~(wait)) begin
            $error("RVALID not asserted");
            break;
        end
        
        $display("[READ] Beat %0d: Data = %h, RRESP = %b", 
                i++, arbif_pkt.RDATA, arbif_pkt.RRESP);

        //Detect if RLAST is asserted
        if (arbif_pkt.RLAST) begin
        $display("[READ] Last data beat received.");
        end
    end
    
    //Turn off RREADY after on cycle of the last burst
    @(negedge arbif_pkt.ACLK)
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
    read_data = {15{0}};
  end else begin
    rresp_golden = 2'b00;  
    for (int i = 0; i < num_beats; i++)
        read_data[i] = test_mem[word_addr +]
  end
endfunction

endmodule
