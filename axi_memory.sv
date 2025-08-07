module axi4_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,    // For 1024 locations
    parameter DEPTH = 1024
)(
    arb_if.memory arbif
);

    // Memory array
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    
    integer j;
    
    // Memory write
    always @(posedge arbif.ACLK) begin
        if (~arbif.ARESETn)
            arbif.mem_rdata <= 0;
        else if (arbif.mem_en) begin
            if (arbif.mem_we)       
                memory[arbif.mem_addr] <= arbif.mem_wdata;
             else 
               arbif.mem_rdata <= memory[arbif.mem_addr];
        end
    end
    
    // Initialize memory
    initial begin
        for (j = 0; j < DEPTH; j = j + 1)
            memory[j] = 0;
    end

endmodule
