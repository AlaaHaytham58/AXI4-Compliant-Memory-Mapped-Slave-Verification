module Top;
	bit ACLK;
	always #5ns ACLK = ~ACLK;

    //write test	
    arb_if arbif_write (ACLK);
    axi4 axi_write (arbif_write.axi);

    //read test
    arb_if arbif_read (ACLK);
    axi4 axi_read (arbif_read.axi);
    
    //memory test
    arb_if arbif_memory (ACLK);
    axi4_memory mem (arbif_memory.memory);
    axi4_memory_tb mem_tb (arbif_memory.mem_tb);
    

endmodule

interface arb_if (input bit ACLK);
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 10;    // For 1024 locations
    parameter MEMORY_DEPTH = 1024;

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
    logic mem_en, mem_we;
    logic [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wdata;
    logic [DATA_WIDTH-1:0] mem_rdata;

    modport axi (
        input ACLK, ARESETn, 
        AWADDR, AWLEN, AWSIZE, AWVALID, 
        WDATA, WLAST, WVALID, 
        BREADY, 
        ARADDR,ARLEN, ARSIZE, ARVALID, 
        RREADY, mem_rdata,
        output AWREADY, WREADY, 
        BRESP, BVALID, 
        ARREADY,
        RDATA,RRESP,RLAST,RVALID,
        mem_en, mem_we, mem_addr, mem_wdata
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

endinterface
