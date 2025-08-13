module axi_assertions_module #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    arb_if.axi axi
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // ------------------ Handshake  ------------------
    property handshake(val, rdy);
        @(posedge axi.ACLK) disable iff (!axi.ARESETn) 
        val |-> ##[0:$] rdy;
    endproperty

    assert property (handshake(axi.AWVALID, axi.AWREADY));
    assert property (handshake(axi.WVALID,  axi.WREADY));
    assert property (handshake(axi.ARVALID, axi.ARREADY));
    assert property (handshake(axi.RVALID,  axi.RREADY));

    // ------------------ Address alignment ------------------
    property addr_alignment(addr, size);
        @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        (axi.AWVALID && axi.AWREADY) |-> (addr % (1 << size) == 0);
    endproperty

    assert property (addr_alignment(axi.AWADDR, axi.AWSIZE));
    assert property (addr_alignment(axi.ARADDR, axi.ARSIZE));

    
    // ------------------ Responses after handshake ------------------
    property b_response;
        @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        (axi.AWVALID && axi.AWREADY && axi.WVALID && axi.WREADY && axi.WLAST)
            |-> ##[1:$] axi.BVALID;
    endproperty

    assert property (b_response);

    property r_response;
        @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        (axi.ARVALID && axi.ARREADY) |-> ##[1:$] axi.RVALID;
    endproperty

    assert property (r_response);

    // ------------------ BRESP and RRESP values ------------------
    assert property (@(posedge axi.ACLK) disable iff (!axi.ARESETn)
        axi.BVALID |-> (axi.BRESP inside {2'b00, 2'b10})
    );
    assert property (@(posedge axi.ACLK) disable iff (!axi.ARESETn)
        axi.RVALID |-> (axi.RRESP inside {2'b00, 2'b10})
    );

    // ------------------ Data integrity ------------------
    property mem_write_integrity;
        @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        (axi.WVALID && axi.WREADY && axi.AWVALID && axi.AWREADY)
            |-> mem[axi.AWADDR] == (axi.WDATA & axi.WSTRB);
    endproperty

    property mem_read_integrity;
        @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        (axi.ARVALID && axi.ARREADY) |-> axi.RDATA == mem[axi.ARADDR];
    endproperty

endmodule
