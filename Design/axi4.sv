module axi4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEMORY_DEPTH = 1024
)(
    arb_if.axi arbif
);

    wire ACLK;
    assign ACLK = arbif.ACLK;
    wire ARESETn;
    assign ARESETn = arbif.ARESETn;

    // Write address channel
    wire [ADDR_WIDTH-1:0] AWADDR = arbif.AWADDR;
    wire [7:0]  AWLEN   = arbif.AWLEN;
    wire [2:0]  AWSIZE  = arbif.AWSIZE;
    wire        AWVALID = arbif.AWVALID;
    reg         AWREADY;
    assign arbif.AWREADY = AWREADY;

    // Write data channel
    wire [DATA_WIDTH-1:0] WDATA = arbif.WDATA;
    wire WVALID = arbif.WVALID;
    wire WLAST  = arbif.WLAST;
    reg  WREADY;
    assign arbif.WREADY = WREADY;

    // Write response channel
    reg  [1:0] BRESP;
    reg        BVALID;
    wire       BREADY = arbif.BREADY;
    assign arbif.BRESP  = BRESP;
    assign arbif.BVALID = BVALID;

    // Read address channel
    wire [ADDR_WIDTH-1:0] ARADDR = arbif.ARADDR;
    wire [7:0]  ARLEN   = arbif.ARLEN;
    wire [2:0]  ARSIZE  = arbif.ARSIZE;
    wire        ARVALID = arbif.ARVALID;
    reg         ARREADY;
    assign arbif.ARREADY = ARREADY;

    // Read data channel
    reg [DATA_WIDTH-1:0] RDATA;
    reg [1:0]  RRESP;
    reg        RVALID;
    reg        RLAST;
    wire       RREADY = arbif.RREADY;
    assign arbif.RDATA  = RDATA;
    assign arbif.RRESP  = RRESP;
    assign arbif.RVALID = RVALID;
    assign arbif.RLAST  = RLAST;

    // Internal memory signals
    reg mem_en, mem_we;
    reg [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    reg [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;
    
    assign arbif.mem_en    = mem_en;
    assign arbif.mem_we    = mem_we;
    assign arbif.mem_addr  = mem_addr;
    assign arbif.mem_wdata = mem_wdata;
    assign mem_rdata       = arbif.mem_rdata;

    // Address and burst management
    reg [ADDR_WIDTH-1:0] write_addr, read_addr;
    reg [7:0] write_burst_len, read_burst_len;
    reg [7:0] write_burst_cnt, read_burst_cnt;
    reg [2:0] write_size, read_size;
    
    wire [ADDR_WIDTH-1:0] write_addr_incr = (1 << write_size);
    wire [ADDR_WIDTH-1:0] read_addr_incr  = (1 << read_size);

    // Boundary/validity flags
    reg write_boundary_cross, read_boundary_cross;
    reg write_addr_valid, read_addr_valid;

    // Memory instance
    // axi4_memory #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .ADDR_WIDTH($clog2(MEMORY_DEPTH)),
    //     .DEPTH(MEMORY_DEPTH)
    // ) mem_inst (
    //     .clk(ACLK),
    //     .rst_n(ARESETn),
    //     .mem_en(mem_en),
    //     .mem_we(mem_we),
    //     .mem_addr(mem_addr),
    //     .mem_wdata(mem_wdata),
    //     .mem_rdata(mem_rdata)
    // );

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
            AWREADY <= 1'b1;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00;

            ARREADY <= 1'b1;
            RVALID  <= 1'b0;
            RRESP   <= 2'b00;
            RDATA   <= {DATA_WIDTH{1'b0}};
            RLAST   <= 1'b0;

            // Reset internal state
            write_state <= W_IDLE;
            read_state  <= R_IDLE;
            mem_en      <= 1'b0;
            mem_we      <= 1'b0;
            mem_addr    <= {$clog2(MEMORY_DEPTH){1'b0}};
            mem_wdata   <= {DATA_WIDTH{1'b0}};

            // Reset address tracking
            write_addr       <= {ADDR_WIDTH{1'b0}};
            read_addr        <= {ADDR_WIDTH{1'b0}};
            write_burst_len  <= 8'b0;
            read_burst_len   <= 8'b0;
            write_burst_cnt  <= 8'b0;
            read_burst_cnt   <= 8'b0;
            write_size       <= 3'b0;
            read_size        <= 3'b0;

            write_boundary_cross <= 1'b0;
            read_boundary_cross  <= 1'b0;
            write_addr_valid     <= 1'b0;
            read_addr_valid      <= 1'b0;

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
                    WREADY  <= 1'b0;
                    BVALID  <= 1'b0;
                    if (AWVALID && AWREADY) begin
                        write_addr      <= AWADDR;
                        write_burst_len <= AWLEN;
                        write_burst_cnt <= AWLEN;
                        write_size      <= AWSIZE;

                        // boundary and validity checks
                        write_boundary_cross <= ((AWADDR & 12'hFFF) + (AWLEN << AWSIZE)) > 12'hFFF;
                        write_addr_valid     <= (AWADDR >> 2) < MEMORY_DEPTH;

                        AWREADY     <= 1'b0;
                        write_state <= W_ADDR;
                    end
                end

                W_ADDR: begin
                    WREADY      <= 1'b1;
                    write_state <= W_DATA;
                end

                W_DATA: begin
                    if (WVALID && WREADY) begin
                        if (write_addr_valid && !write_boundary_cross) begin
                            mem_en    <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= write_addr >> 2;
                            mem_wdata <= WDATA;
                        end
                        
                        if (WLAST || write_burst_cnt == 0) begin
                            WREADY      <= 1'b0;
                            write_state <= W_RESP;

                            if (!write_addr_valid || write_boundary_cross)
                                BRESP <= 2'b10; // SLVERR
                            else
                                BRESP <= 2'b00; // OKAY
                            BVALID <= 1'b1;
                        end else begin
                            write_addr      <= write_addr + write_addr_incr;
                            write_burst_cnt <= write_burst_cnt - 1'b1;
                        end
                    end
                end

                W_RESP: begin
                    if (BREADY && BVALID) begin
                        BVALID      <= 1'b0;
                        BRESP       <= 2'b00;
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
                    RVALID  <= 1'b0;
                    RLAST   <= 1'b0;

                    if (ARVALID && ARREADY) begin
                        read_addr      <= ARADDR;
                        read_burst_len <= ARLEN;
                        read_burst_cnt <= ARLEN;
                        read_size      <= ARSIZE;

                        // boundary and validity checks
                        read_boundary_cross <= ((ARADDR & 12'hFFF) + (ARLEN << ARSIZE)) > 12'hFFF;
                        read_addr_valid     <= (ARADDR >> 2) < MEMORY_DEPTH;

                        ARREADY     <= 1'b0;
                        read_state  <= R_ADDR;
                    end
                end

                R_ADDR: begin
                    if (read_addr_valid && !read_boundary_cross)
                        RRESP <= 2'b00;
                    else
                        RRESP <= 2'b10;

                    RVALID <= 1'b1;
                    RLAST  <= (read_burst_cnt == 0);

                    if (RREADY && RVALID) begin
                        RVALID <= 1'b0;

                        if (read_burst_cnt > 0) begin
                            read_addr      <= read_addr + read_addr_incr;
                            read_burst_cnt <= read_burst_cnt - 1'b1;

                            if (read_addr_valid && !read_boundary_cross) begin
                                mem_en   <= 1'b1;
                                mem_addr <= (read_addr + read_addr_incr) >> 2;
                                RDATA    <= mem_rdata; // latch new data
                            end
                        end else begin
                            RLAST      <= 1'b0;
                            read_state <= R_IDLE;
                        end
                    end
                end

                default: read_state <= R_IDLE;
            endcase
        end
    end

endmodule
