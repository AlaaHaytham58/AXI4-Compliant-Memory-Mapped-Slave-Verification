module axi4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEMORY_DEPTH = 1024
)(
    input  wire                     ACLK,
    input  wire                     ARESETn,

    // Write address channel
    input  wire [ADDR_WIDTH-1:0]    AWADDR,
    input  wire [7:0]               AWLEN,
    input  wire [2:0]               AWSIZE,
    input  wire                     AWVALID,
    output reg                      AWREADY,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]    WDATA,
    input  wire                     WVALID,
    input  wire                     WLAST,
    output reg                      WREADY,

    // Write response channel
    output reg [1:0]                BRESP,
    output reg                      BVALID,
    input  wire                     BREADY,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]    ARADDR,
    input  wire [7:0]               ARLEN,
    input  wire [2:0]               ARSIZE,
    input  wire                     ARVALID,
    output reg                      ARREADY,

    // Read data channel
    output reg [DATA_WIDTH-1:0]     RDATA,
    output reg [1:0]                RRESP,
    output reg                      RVALID,
    output reg                      RLAST,
    input  wire                     RREADY
);


    // Internal memory signals
    reg mem_en, mem_we;
    reg [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    reg [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;

    // Address and burst management
    reg [ADDR_WIDTH-1:0] write_addr, read_addr;
    reg [7:0] write_burst_len, read_burst_len;
    reg [7:0] write_burst_cnt, read_burst_cnt;
    reg [2:0] write_size, read_size;
    
    wire [ADDR_WIDTH-1:0] write_addr_incr,read_addr_incr;
    
    
    
    // Address increment calculation
    assign  write_addr_incr = (1 << write_size);
    assign  read_addr_incr  = (1 << read_size);
    
    // Address boundary check (4KB boundary = 12 bits)
    assign write_boundary_cross = ((write_addr & 12'hFFF) + (write_burst_len << write_size)) > 12'hFFF;
    assign read_boundary_cross = ((read_addr & 12'hFFF) + (read_burst_len << read_size)) > 12'hFFF;
    
    // Address range check
    assign write_addr_valid = (write_addr >> 2) < MEMORY_DEPTH;
    assign read_addr_valid = (read_addr >> 2) < MEMORY_DEPTH;

    // Memory instance
    axi4_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MEMORY_DEPTH)),
        .DEPTH(MEMORY_DEPTH)
    ) mem_inst (
        .clk(ACLK),
        .rst_n(ARESETn),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata)
    );

    // FSM states
    reg [2:0] write_state;
    localparam W_IDLE = 3'd0,
               W_ADDR = 3'd1,
               W_DATA = 3'd2,
               W_RESP = 3'd3;

    reg [2:0] read_state;
    localparam R_IDLE = 3'd0,
               R_ADDR = 3'd1,
               R_DATA = 3'd2;

    // Registered memory read data for timing
    reg [DATA_WIDTH-1:0] mem_rdata_reg;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            // Reset all outputs
            AWREADY <= 1'b1;  // Ready to accept address
            WREADY <= 1'b0;
            BVALID <= 1'b0;
            BRESP <= 2'b00;
            
            ARREADY <= 1'b1;  // Ready to accept address
            RVALID <= 1'b0;
            RRESP <= 2'b00;
            RDATA <= {DATA_WIDTH{1'b0}};
            RLAST <= 1'b0;
            
            // Reset internal state
            write_state <= W_IDLE;
            read_state <= R_IDLE;
            mem_en <= 1'b0;
            mem_we <= 1'b0;
            mem_addr <= {$clog2(MEMORY_DEPTH){1'b0}};
            mem_wdata <= {DATA_WIDTH{1'b0}};
            
            // Reset address tracking
            write_addr <= {ADDR_WIDTH{1'b0}};
            read_addr <= {ADDR_WIDTH{1'b0}};
            write_burst_len <= 8'b0;
            read_burst_len <= 8'b0;
            write_burst_cnt <= 8'b0;
            read_burst_cnt <= 8'b0;
            write_size <= 3'b0;
            read_size <= 3'b0;
            
            mem_rdata_reg <= {DATA_WIDTH{1'b0}};
            
        end else begin
            // Default memory disable
            mem_en <= 1'b0;
            mem_we <= 1'b0;

            // --------------------------
            // Write Channel FSM
            // --------------------------
            case (write_state)
                W_IDLE: begin
                    AWREADY <= 1'b1;
                    WREADY <= 1'b0;
                    BVALID <= 1'b0;
                    
                    if (AWVALID && AWREADY) begin
                        // Capture address phase information
                        write_addr <= AWADDR;
                        write_burst_len <= AWLEN;
                        write_burst_cnt <= AWLEN;
                        write_size <= AWSIZE;
                        
                        AWREADY <= 1'b0;
                        write_state <= W_ADDR;
                    end
                end
                
                W_ADDR: begin
                    // Transition to data phase
                    WREADY <= 1'b1;
                    write_state <= W_DATA;
                end
                
                W_DATA: begin
                    if (WVALID && WREADY) begin
                        // Check if address is valid
                        if (write_addr_valid && !write_boundary_cross) begin
                            // Perform write operation
                            mem_en <= 1'b1;
                            mem_we <= 1'b1;
                            mem_addr <= write_addr >> 2;  // Convert to word address
                            mem_wdata <= WDATA;
                        end
                        
                        // Check for last transfer
                        if (WLAST || write_burst_cnt == 0) begin
                            WREADY <= 1'b0;
                            write_state <= W_RESP;
                            
                            // Set response - delayed until write completion
                            if (!write_addr_valid || write_boundary_cross) begin
                                BRESP <= 2'b10;  // SLVERR
                            end else begin
                                BRESP <= 2'b00;  // OKAY
                            end
                            BVALID <= 1'b1;
                        end else begin
                            // Continue burst - increment address
                            write_addr <= write_addr + write_addr_incr;
                            write_burst_cnt <= write_burst_cnt - 1'b1;
                        end
                    end
                end
                
                W_RESP: begin
                    if (BREADY && BVALID) begin
                        BVALID <= 1'b0;
                        BRESP <= 2'b00;
                        write_state <= W_IDLE;
                    end
                end
                
                default: write_state <= W_IDLE;
            endcase

            // --------------------------
            // Read Channel FSM
            // --------------------------
            case (read_state)
                R_IDLE: begin
                    ARREADY <= 1'b1;
                    RVALID <= 1'b0;
                    RLAST <= 1'b0;
                    
                    if (ARVALID && ARREADY) begin
                        // Capture address phase information
                        read_addr <= ARADDR;
                        read_burst_len <= ARLEN;
                        read_burst_cnt <= ARLEN;
                        read_size <= ARSIZE;
                        
                        ARREADY <= 1'b0;
                        read_state <= R_ADDR;
                    end
                end
                
                R_ADDR: begin
                    // Start first read
                    if (read_addr_valid && !read_boundary_cross) begin
                        mem_en <= 1'b1;
                        mem_addr <= read_addr >> 2;  // Convert to word address
                    end
                    read_state <= R_DATA;
                end
                
                R_DATA: begin
                    // Present read data
                    if (read_addr_valid && !read_boundary_cross) begin
                        RDATA <= mem_rdata;
                        RRESP <= 2'b00;  // OKAY
                    end else begin
                        RDATA <= {DATA_WIDTH{1'b0}};
                        RRESP <= 2'b10;  // SLVERR
                    end
                    
                    RVALID <= 1'b1;
                    RLAST <= (read_burst_cnt == 0);
                    
                    if (RREADY && RVALID) begin
                        RVALID <= 1'b0;
                        
                        if (read_burst_cnt > 0) begin
                            // Continue burst
                            read_addr <= read_addr + read_addr_incr;
                            read_burst_cnt <= read_burst_cnt - 1'b1;
                            
                            // Start next read
                            if (read_addr_valid && !read_boundary_cross) begin
                                mem_en <= 1'b1;
                                mem_addr <= (read_addr + read_addr_incr) >> 2;
                            end
                            
                            // Stay in R_DATA for next transfer
                        end else begin
                            // End of burst
                            RLAST <= 1'b0;
                            read_state <= R_IDLE;
                        end
                    end
                end
                
                default: read_state <= R_IDLE;
            endcase
        end
    end

endmodule