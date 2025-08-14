interface arb_if #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16, DEPTH = 1024) (input bit ACLK);

    //Active low reset
    bit ARESETn;

    //memory signals
    logic mem_en, mem_we;
    logic [$clog2(DEPTH)-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wdata;
    logic [DATA_WIDTH-1:0] mem_rdata;

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
