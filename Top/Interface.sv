interface arb_if #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16, DEPTH = 1024) (input bit ACLK);

    //Active low reset
    bit ARESETn;

    //Address write signals 
    logic [ADDR_WIDTH - 1:0] AWADDR;
    logic [7:0] AWLEN;
    logic [2:0] AWSIZE;
    logic AWVALID, AWREADY;

    //Data write signals
    logic [DATA_WIDTH - 1:0] WDATA;
    logic WLAST, WVALID, WREADY;

    //Write Response signals
    logic [1:0] BRESP;
    logic BVALID,BREADY;

    //Address read signals
    logic [ADDR_WIDTH - 1:0] ARADDR;
    logic [7:0] ARLEN;
    logic [2:0] ARSIZE;
    logic ARVALID, ARREADY;

    //Data read signals
    logic [DATA_WIDTH - 1:0] RDATA;
    logic RLAST, RVALID, RREADY;

    //Read response
    logic [1:0] RRESP;

    //memory signals
    //memory signals
    logic mem_en, mem_we;
    logic [$clog2(DEPTH)-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wdata;
    logic [DATA_WIDTH-1:0] mem_rdata;

    modport axi (
        input ACLK, ARESETn, 
        AWADDR, AWLEN, AWSIZE, AWVALID, 
        WDATA, WLAST, WVALID, 
        BREADY, 
        ARADDR,ARLEN, ARSIZE, ARVALID, 
        RREADY,
        mem_rdata,

        output AWREADY, WREADY, 
        BRESP, BVALID, 
        ARREADY,
        RDATA,RRESP,RLAST,RVALID, 
        mem_en, mem_we, mem_addr, mem_wdata

    );

    modport axi_tb (
        input ACLK, AWREADY, WREADY, 
        BRESP, BVALID, 
        ARREADY,
        RDATA,RRESP,RLAST,RVALID,

        output ARESETn, 
        AWADDR, AWLEN, AWSIZE, AWVALID, 
        WDATA, WLAST, WVALID, 
        BREADY, 
        ARADDR,ARLEN, ARSIZE, ARVALID, 
        RREADY
    );


    modport memory (
        input ACLK, ARESETn, mem_en,mem_we,mem_addr,mem_wdata,
        output mem_rdata
    );

    modport mem_tb (
        input ACLK,
        input mem_rdata,
        output ARESETn, mem_en, mem_we, mem_addr, mem_wdata
    );

    modport monitor(
        input ACLK, ARESETn, 
        AWADDR, AWLEN, AWSIZE, AWVALID, 
        WDATA, WLAST, WVALID, 
        BREADY, 
        ARADDR,ARLEN, ARSIZE, ARVALID, 
        RREADY, mem_rdata,
         AWREADY, WREADY, 
        BRESP, BVALID, 
        ARREADY,
        RDATA,RRESP,RLAST,RVALID,
        mem_en, mem_we, mem_addr, mem_wdata
    );
endinterface
