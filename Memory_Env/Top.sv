
module Top;

    bit ACLK = 0;
    always #5 ACLK = ~ACLK;

    arb_if          arbif_memory (ACLK);

    axi4_memory DUT #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     ($clog2(MEMORY_DEPTH)),
        .DEPTH          (MEMORY_DEPTH)
    ) mem_inst (
        .clk            (ACLK),
        .rst_n          (arbif_memory.ARESETn),
        .mem_en         (arbif_memory.mem_en),
        .mem_we         (arbif_memory.mem_we),
        .mem_addr       (arbif_memory.mem_addr),
        .mem_wdata      (arbif_memory.mem_wdata),
        .mem_rdata      (arbif_memory.mem_rdata)
    );
    
    axi4_memory_tb  mem_tb (arbif_memory.mem_tb)

endmodule

