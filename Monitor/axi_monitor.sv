module axi4_monitor #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
) (
    arb_if.monitor axi_if
);

    integer logfile;

    covergroup axi_cov @(posedge axi_if.ACLK);
        coverpoint axi_if.AWVALID { bins awvalid = {1}; }
        coverpoint axi_if.WVALID  { bins wvalid  = {1}; }
        coverpoint axi_if.BVALID  { bins bvalid  = {1}; }
        coverpoint axi_if.ARVALID { bins arvalid = {1}; }
        coverpoint axi_if.RVALID  { bins rvalid  = {1}; }
    endgroup

    axi_cov cg = new();

    initial begin
        logfile = $fopen("axi_monitor_log.txt", "w");
        if (!logfile) begin
            $display("ERROR: Could not open logfile.");
            $finish;
        end
    end


    always @(negedge axi_if.ACLK) begin
        // write address handshake
        if (axi_if.AWVALID && axi_if.AWREADY) begin
            $fwrite(logfile, "[%0t] AWADDR = %h, AWLEN = %0d\n", 
                    $time, axi_if.AWADDR, axi_if.AWLEN);
            cg.sample();
        end

        // write data
        if (axi_if.WVALID && axi_if.WREADY) begin
            $fwrite(logfile, "[%0t] WDATA = %h, WLAST = %b AWADDR = %h, AWLEN = %0d\n", 
                    $time, axi_if.WDATA, axi_if.WLAST,axi_if.AWADDR, axi_if.AWLEN);
            cg.sample();
        end

        // write response
        if (axi_if.BVALID && axi_if.BREADY) begin
            $fwrite(logfile, "[%0t] BRESP = %b\n", $time, axi_if.BRESP);
            cg.sample();
        end

        // read address
        if (axi_if.ARVALID && axi_if.ARREADY) begin
            $fwrite(logfile, "[%0t] ARADDR = %h, ARLEN = %0d\n", 
                    $time, axi_if.ARADDR, axi_if.ARLEN);
            cg.sample();
        end

        // read data
        if (axi_if.RVALID && axi_if.RREADY) begin
            $fwrite(logfile, "[%0t] RDATA = %h, RLAST = %b, RRESP = %b ARADDR = %h, ARLEN = %0d\n", 
                    $time, axi_if.RDATA, axi_if.RLAST, axi_if.RRESP,axi_if.ARADDR, axi_if.ARLEN);
            cg.sample();
        end
    end

endmodule
