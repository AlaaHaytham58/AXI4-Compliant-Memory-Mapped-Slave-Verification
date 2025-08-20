`include "../Packages/axi_constraints.sv"

module axi4_tb #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 16,
    parameter MEMORY_DEPTH = 1024
)(
    arb_if arbif_pkt
);

    import axi_enum_packet::*;
    import axi_packet_all::*;

    axi_packet #(ADDR_WIDTH, DATA_WIDTH, MEMORY_DEPTH) pkt;

    bit [1:0] golden_resp;
    bit [1:0] captured_resp;
    bit [1:0] expected_rresp;

    // ---------------- Read Output Struct ----------------
    typedef struct {
        bit [DATA_WIDTH-1:0] data;
        bit [1:0] resp;
        bit last;
    } read_out;

    // Queues to hold read data
    read_out read_data[$];

    // Wait counter
    int wait_valid;

    // Reference memory
    reg [DATA_WIDTH-1:0] test_mem [0:MEMORY_DEPTH-1];
    // ---------------- Initialization ----------------
    initial begin
        // Initialize memory
        for (int i = 0; i < MEMORY_DEPTH; i++)
            test_mem[i] = i;

        arbif_pkt.ARESETn = 0;
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARESETn = 1;

        repeat (500) begin
            pkt = new();
            generate_stimulus(pkt);

            if (pkt.axi_access == ACCESS_WRITE) begin
                drive_write(pkt);
                if (wait_valid <= 0) begin
                    $error("AWREADY/WREADY timeout");
                    continue;
                end
                collect_response(captured_resp);
                golden_model_write(pkt, golden_resp);
                check_wdata(pkt);
            end
            else begin
                drive_read(pkt);
                if (wait_valid <= 0) begin
                    $error("ARREADY timeout");
                    continue;
                end
                collect_rdata(pkt);
                if (wait_valid <= 0) begin
                    $error("RVALID timeout");
                    continue;
                end
                golden_model_read(pkt, expected_rresp);
                read_compare(pkt);
            end

            pkt.cg.sample();
        end

        $stop;
    end
    // ---------------- Stimulus ----------------
    function automatic void generate_stimulus(ref axi_packet pkt);
        assert(pkt.randomize()) else begin
            $display("Randomization failed");
            $stop;
        end

        if (pkt.axi_access == ACCESS_WRITE)
            pkt.randarr();   // Prepare write data
        else
            pkt.randread();  // Prepare read data
    endfunction
    // ---------------- Write Tasks ----------------
    task automatic drive_write(ref axi_packet write);
        $display("Write Started");
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWLEN   = write.awlen;
        arbif_pkt.AWSIZE  = write.awsize;
        arbif_pkt.BREADY  = 1;
        arbif_pkt.AWADDR  = write.awaddr;
        arbif_pkt.AWVALID = 1;

        $display("Writing to Address: %0h", arbif_pkt.AWADDR);

        wait_valid = 500;
        while (~arbif_pkt.AWREADY) begin
            @(negedge arbif_pkt.ACLK);
            if (!(--wait_valid)) begin
                $error("AWREADY timeout");
                break;
            end
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWVALID = 0;

        for (int i = 0; i <= write.awlen; i++) begin
            @(negedge arbif_pkt.ACLK);
            arbif_pkt.WDATA  = write.data_array[i];
            arbif_pkt.WVALID = 1;
            arbif_pkt.WLAST  = (i == write.awlen);

            $display("Waiting on WREADY...");
            while (~arbif_pkt.WREADY) begin
                @(negedge arbif_pkt.ACLK);
                if (!(--wait_valid)) begin
                    $error("WREADY timeout");
                    break;
                end
            end

            $display("Writing data: Addr=%0h, Data=%0h", write.awaddr + i*4, write.data_array[i]);
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.WVALID = 0;
        arbif_pkt.WLAST  = 0;
        arbif_pkt.WDATA  = 0;
    endtask

    task automatic collect_response(output bit [1:0] bresp);
        $display("Waiting on BVALID...");
        wait_valid = 500;
        while (~arbif_pkt.BVALID) begin
            @(negedge arbif_pkt.ACLK);
            if (!(--wait_valid)) begin
                $error("BVALID timeout");
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
            for (int i = 0; i <= write.awlen; i++) begin
                test_mem[(write.awaddr + i*4) >> 2] = write.data_array[i];
                $display("Golden Memory Write: Addr=%0h, Data=%0h", write.awaddr + i*4, write.data_array[i]);
            end
        end else bresp = 2'b10;
    endtask

    task automatic check_wdata(ref axi_packet pkt);
        pkt.arlen  = pkt.awlen;
        pkt.arsize = pkt.awsize;
        pkt.araddr = pkt.awaddr;

        drive_read(pkt);
        if (wait_valid <= 0) begin $error("ARREADY timeout"); return; end
        collect_rdata(pkt);
        if (wait_valid <= 0) begin $error("RVALID timeout"); return; end
        golden_model_read(pkt, expected_rresp);
        read_compare(pkt);
    endtask
    // ---------------- Read Tasks ----------------
    task automatic drive_read(ref axi_packet pkt);
        $display("Read Started");
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARLEN   = pkt.arlen;
        arbif_pkt.ARSIZE  = pkt.arsize;
        arbif_pkt.ARADDR  = pkt.araddr;
        arbif_pkt.ARVALID = 1;

        $display("Reading from Address: %0h", arbif_pkt.ARADDR);

        wait_valid = 500;
        while (~arbif_pkt.ARREADY) begin
            @(negedge arbif_pkt.ACLK);
            if (!(--wait_valid)) begin
                $error("ARREADY timeout");
                break;
            end
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARVALID = 0;
    endtask

   // ---------------- Read Tasks  ----------------
task automatic collect_rdata(ref axi_packet pkt);
    int beat = 0;
    int num_beats = pkt.arlen + 1;
    read_data = {};           
    arbif_pkt.RREADY = 1;     

    $display("Collecting read data...");

    for (int i = 0; i < num_beats; i++) begin
        @(negedge arbif_pkt.ACLK);

        if (((pkt.araddr >> 2) + i) < MEMORY_DEPTH) begin
            arbif_pkt.RDATA  = test_mem[(pkt.araddr >> 2) + i];
            arbif_pkt.RRESP  = 2'b00;   
        end else begin
            arbif_pkt.RDATA  = '0;
            arbif_pkt.RRESP  = 2'b10;   
        end

        arbif_pkt.RLAST  = (i == num_beats-1);
        arbif_pkt.RVALID = 1;  

        read_data.push_back('{data: arbif_pkt.RDATA,
                             resp: arbif_pkt.RRESP,
                             last: arbif_pkt.RLAST});

        $display("[READ] Beat %0d: Data=%0h, RRESP=%b, LAST=%b",
                 beat, arbif_pkt.RDATA, arbif_pkt.RRESP, arbif_pkt.RLAST);

        beat++;
        @(negedge arbif_pkt.ACLK);

        arbif_pkt.RVALID = 0;
    end

    arbif_pkt.RREADY = 0;
endtask

// ---------------- Golden Model Read ----------------
task automatic golden_model_read(ref axi_packet pkt, output bit [1:0] rresp);
    int start_addr = pkt.araddr;
    int word_addr  = start_addr >> 2;
    int num_beats  = pkt.arlen + 1;
    pkt.rdata = new[num_beats];

    for (int i = 0; i < num_beats; i++) begin
        if ((word_addr + i) < MEMORY_DEPTH) begin
            pkt.rdata[i] = test_mem[word_addr + i];
        end else begin
            pkt.rdata[i] = '0;
        end
    end

    rresp = 2'b00;
    for (int i = 0; i < num_beats; i++) begin
        if ((word_addr + i) >= MEMORY_DEPTH) begin
            rresp = 2'b10;  // SLVERR
            break;
        end
    end
endtask

    function automatic read_compare(ref axi_packet pkt);
        for (int i = 0; i < read_data.size(); i++) begin
            if (pkt.rdata[i] == read_data[i].data)
                $display("Read OK: Data=%h", read_data[i].data);
            else
                $display("Read FAIL: Expected=%h, Actual=%h", pkt.rdata[i], read_data[i].data);
        end
    endfunction

endmodule