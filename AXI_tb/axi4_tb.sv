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

    // Packet object
    axi_packet #(ADDR_WIDTH, DATA_WIDTH, MEMORY_DEPTH) pkt;

    // Response tracking
    bit [1:0] golden_resp;
    bit [1:0] captured_resp;
    bit [1:0] expected_rresp;

    // ---------------- Read Output Struct ----------------
    typedef struct {
        bit [DATA_WIDTH-1:0] data;
        bit [1:0]            resp;
        bit                  last;
    } read_out;

    // Arrays to hold read/expected data
    read_out read_data[];
    read_out expected_data[];

    // Wait counter
    int wait_valid;

    // Reference memory
    reg [DATA_WIDTH-1:0] test_mem [0:MEMORY_DEPTH-1];

    // ---------------- Initialization ----------------
    initial begin
        // Initialize memory with some test data
        for (int i = 0; i < MEMORY_DEPTH; i++) begin
            test_mem[i] = i; 
        end

        arbif_pkt.ARESETn = 0;
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARESETn = 1;

        repeat (500) begin
            pkt = new();
            generate_stimulus(pkt);

            if (pkt.axi_access == ACCESS_WRITE) begin
                drive_write(pkt);
                if (wait_valid <= 0) begin
                    $error("Couldn't Continue the test case, ARREADY took too long to respond");
                    continue;
                end

                collect_response(captured_resp);
                golden_model_write(pkt, golden_resp);
                check_wdata(pkt);
            end
            else begin
                drive_read(pkt);

                if (wait_valid <= 0) begin
                    $error("Couldn't Continue the test case, ARREADY took too long to respond");
                    continue;
                end

                collect_rdata(pkt);

                if (wait_valid <= 0) begin
                    $error("Couldn't Continue the test case, RVALID took too long to respond");
                    continue;
                end

                golden_model_read(pkt, expected_rresp);
                read_compare(pkt);
            end

            pkt.cg.sample();
        end

        $stop;
    end

    // ---------------- Write Functionality ----------------
    function automatic void generate_stimulus(ref axi_packet pkt);
        assert(pkt.randomize()) else begin
            $display("Randomization failed");
            $stop;
        end
        if (pkt.axi_access == ACCESS_WRITE) begin
            pkt.randarr();     // golden write reference
        end
        else begin
            pkt.randread();    // AXI RDATA golden model
        end
    endfunction

    task automatic drive_write(ref axi_packet write);
        $display("Write Started");
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWLEN   = write.awlen;
        arbif_pkt.AWSIZE  = write.awsize;
        arbif_pkt.BREADY  = 1;
        arbif_pkt.AWADDR  = write.awaddr;
        arbif_pkt.AWVALID = 1;

        $display("Writing to Address: %0h", arbif_pkt.AWADDR);
        $display("Waiting on AWREADY......");
        wait_valid = 500;
        while (~arbif_pkt.AWREADY) begin
            @(negedge arbif_pkt.ACLK);
            if (!(--wait_valid)) begin
                $error("AWREADY took too long to be asserted");
                break;
            end
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.AWVALID = 0;

        // Write burst
        for (int i = 0; i <= write.awlen; i++) begin
            @(negedge arbif_pkt.ACLK);
            arbif_pkt.WDATA  = write.data_array[i];
            arbif_pkt.WVALID = 1;
            arbif_pkt.WLAST  = (i == write.awlen);

            $display("Waiting on WREADY......");
            while (~arbif_pkt.WREADY) begin
                @(negedge arbif_pkt.ACLK);
                if (!(--wait_valid)) begin
                    $error("WREADY took too long to be asserted");
                    break;
                end
            end
            $display("Writing data: Address = %0h, Data = %0h", (write.awaddr + i*4), write.data_array[i]);
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.WVALID = 0;
        arbif_pkt.WLAST  = 0;
        arbif_pkt.WDATA  = 0;
    endtask

    task automatic collect_response(output bit [1:0] bresp);
        $display("Waiting on BVALID......");
        wait_valid = 500;
        while (~arbif_pkt.BVALID) begin
            @(negedge arbif_pkt.ACLK);
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
            for (int i = 0; i <= write.awlen; i++) begin
                test_mem[(write.awaddr + i*4) >> 2] = write.data_array[i];
                $display("Writing to memory: Address = %0h, Data = %0h", (write.awaddr + i*4), write.data_array[i]);
            end
        end
        else bresp = 2'b10;
    endtask

    task automatic check_wdata(ref axi_packet pkt);
        $display("Reading from memory to make sure data is added correctly...");
        pkt.arlen  = pkt.awlen;
        pkt.arsize = pkt.awsize;
        pkt.araddr = pkt.awaddr;

        drive_read(pkt);

        if (wait_valid <= 0) begin
            $error("Couldn't Continue the test case, ARREADY took too long to respond");
            return;
        end

        collect_rdata(pkt);

        if (wait_valid <= 0) begin
            $error("Couldn't Continue the test case, RVALID took too long to respond");
            return;
        end

        golden_model_read(pkt, expected_rresp);
        read_compare(pkt);
    endtask

    // ---------------- Read Functionality ----------------
    task automatic drive_read(ref axi_packet pkt);
        $display("Read Started");
        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARLEN   = pkt.arlen;
        arbif_pkt.ARSIZE  = pkt.arsize;
        arbif_pkt.ARADDR  = pkt.araddr;
        arbif_pkt.ARVALID = 1;

        $display("Reading from Address: %0h", arbif_pkt.ARADDR);
        $display("Waiting on ARREADY......");
        wait_valid = 500;
        while (~arbif_pkt.ARREADY) begin
            @(negedge arbif_pkt.ACLK);
            if (!(--wait_valid)) begin
                $error("ARREADY took too long to be asserted");
                break;
            end
        end

        @(negedge arbif_pkt.ACLK);
        arbif_pkt.ARVALID = 0;
    endtask

    task automatic collect_rdata(ref axi_packet pkt);
        int beat = 0;
        int num_beats = pkt.arlen + 1;
        read_data = new[num_beats];

        arbif_pkt.RREADY = 1;
        $display("Collecting read data...");

        while (beat < num_beats) begin
            wait_valid = 500;
            while (~arbif_pkt.RVALID) begin
                @(negedge arbif_pkt.ACLK);
                if (!(--wait_valid)) begin
                    $error("RVALID took too long to be asserted");
                    disable collect_rdata;
                end
            end

            read_data[beat].data = arbif_pkt.RDATA;
            read_data[beat].resp = arbif_pkt.RRESP;
            read_data[beat].last = arbif_pkt.RLAST;

            $display("[READ] Beat %0d: Addr=%0h Data=%0h, RRESP=%b, LAST=%b",
                     beat, pkt.araddr + beat*4, read_data[beat].data,
                     read_data[beat].resp, read_data[beat].last);

            beat++;
            @(negedge arbif_pkt.ACLK);
        end

        arbif_pkt.RREADY = 0;
    endtask

    task automatic golden_model_read(
        ref axi_packet pkt,
        output bit [1:0] rresp
    );
        int start_addr   = pkt.araddr;
        int word_addr    = start_addr >> 2;
        int num_beats    = pkt.arlen + 1;
        int total_bytes  = num_beats * (1 << pkt.arsize);

        bit boundary     = ((start_addr % 4096) + total_bytes > 4096);
        bit out_of_range = ((word_addr + num_beats) > MEMORY_DEPTH);

        pkt.rdata = new[num_beats];

        if (out_of_range || boundary) begin
            rresp = 2'b10; // SLVERR
            for (int i = 0; i < num_beats; i++) begin
                pkt.rdata[i] = '0;
                $display("[GOLDEN][READ_ERR] Addr=%0h -> SLVERR",
                          (start_addr + i*4));
            end
        end
        else begin
            rresp = 2'b00; // OKAY
            for (int i = 0; i < num_beats; i++) begin
                pkt.rdata[i] = test_mem[word_addr + i];
                $display("[GOLDEN][READ_OK] Addr=%0h Data=%0h",
                          (start_addr + i*4), pkt.rdata[i]);
            end
        end
    endtask

    function automatic read_compare(ref axi_packet pkt);
        int num_beats = pkt.arlen + 1;

        for (int i = 0; i < num_beats; i++) begin
            if (pkt.rdata[i] === read_data[i].data)
                $display("read successful, data: %h", read_data[i].data);
            else
                $display("read failed, expected: %h, actual: %h",
                         pkt.rdata[i], read_data[i].data);
        end
    endfunction

endmodule
