module axi4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEMORY_DEPTH = 1024
)(
    arb_if.axi arbif
);

    // Internal memory signals
    reg mem_en, mem_we;
    reg [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    reg [DATA_WIDTH-1:0] mem_wdata;

    assign arbif.mem_en    = mem_en;
    assign arbif.mem_we    = mem_we;
    assign arbif.mem_addr  = mem_addr;
    assign arbif.mem_wdata = mem_wdata;

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

    // ----------------- AXI FSM -----------------
    always @(posedge arbif.ACLK or negedge arbif.ARESETn) begin
        if (!arbif.ARESETn) begin
            // Reset write channel
            arbif.AWREADY <= 1'b1;
            arbif.WREADY  <= 1'b0;
            arbif.BVALID  <= 1'b0;
            arbif.BRESP   <= 2'b00;

            // Reset read channel
            arbif.ARREADY <= 1'b1;
            arbif.RVALID  <= 1'b0;
            arbif.RRESP   <= 2'b00;
            arbif.RDATA   <= {DATA_WIDTH{1'b0}};
            arbif.RLAST   <= 1'b0;

            // Reset internal state
            write_state <= W_IDLE;
            read_state  <= R_IDLE;
            mem_en      <= 1'b0;
            mem_we      <= 1'b0;
            mem_addr    <= {$clog2(MEMORY_DEPTH){1'b0}};
            mem_wdata   <= {DATA_WIDTH{1'b0}};

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

        end else begin
            // Default memory disabled
            mem_en <= 1'b0;
            mem_we <= 1'b0;

            // ---------------- Write FSM ----------------
            case(write_state)
                W_IDLE: begin
                    arbif.AWREADY <= 1'b1;
                    arbif.WREADY  <= 1'b0;
                    arbif.BVALID  <= 1'b0;
                    if (arbif.AWVALID && arbif.AWREADY) begin
                        write_addr      <= arbif.AWADDR;
                        write_burst_len <= arbif.AWLEN;
                        write_burst_cnt <= arbif.AWLEN;
                        write_size      <= arbif.AWSIZE;

                        write_boundary_cross <= ((arbif.AWADDR & 12'hFFF) + (arbif.AWLEN << arbif.AWSIZE)) > 12'hFFF;
                        write_addr_valid     <= (arbif.AWADDR >> 2) < MEMORY_DEPTH;

                        arbif.AWREADY <= 1'b0;
                        write_state <= W_ADDR;
                    end
                end

                W_ADDR: begin
                    arbif.WREADY <= 1'b1;
                    write_state <= W_DATA;
                end

                W_DATA: begin
                    if (arbif.WVALID && arbif.WREADY) begin
                        if (write_addr_valid && !write_boundary_cross) begin
                            mem_en    <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= write_addr >> 2;
                            mem_wdata <= arbif.WDATA;
                        end

                        if (arbif.WLAST || write_burst_cnt == 0) begin
                            arbif.WREADY <= 1'b0;
                            write_state <= W_RESP;

                            arbif.BRESP <= (!write_addr_valid || write_boundary_cross) ? 2'b10 : 2'b00;
                            arbif.BVALID <= 1'b1;
                        end else begin
                            write_addr      <= write_addr + write_addr_incr;
                            write_burst_cnt <= write_burst_cnt - 1'b1;
                        end
                    end
                end

                W_RESP: begin
                    if (arbif.BREADY && arbif.BVALID) begin
                        arbif.BVALID <= 1'b0;
                        arbif.BRESP  <= 2'b00;
                        write_state  <= W_IDLE;
                    end
                end

                default: write_state <= W_IDLE;
            endcase

            // ---------------- Read FSM ----------------
            case(read_state)
                R_IDLE: begin
                    arbif.ARREADY <= 1'b1;
                    arbif.RVALID  <= 1'b0;
                    arbif.RLAST   <= 1'b0;

                    if (arbif.ARVALID && arbif.ARREADY) begin
                        read_addr      <= arbif.ARADDR;
                        read_burst_len <= arbif.ARLEN;
                        read_burst_cnt <= arbif.ARLEN;
                        read_size      <= arbif.ARSIZE;

                        read_boundary_cross <= ((arbif.ARADDR & 12'hFFF) + (arbif.ARLEN << arbif.ARSIZE)) > 12'hFFF;
                        read_addr_valid     <= (arbif.ARADDR >> 2) < MEMORY_DEPTH;

                        arbif.ARREADY <= 1'b0;
                        read_state <= R_ADDR;
                    end
                end

                R_ADDR: begin
                    arbif.RRESP  <= (read_addr_valid && !read_boundary_cross) ? 2'b00 : 2'b10;
                    arbif.RVALID <= 1'b1;
                    arbif.RLAST  <= (read_burst_cnt == 0);

                    if (arbif.RREADY && arbif.RVALID) begin
                        arbif.RVALID <= 1'b0;

                        if (read_burst_cnt > 0) begin
                            read_addr      <= read_addr + read_addr_incr;
                            read_burst_cnt <= read_burst_cnt - 1'b1;

                            if (read_addr_valid && !read_boundary_cross) begin
                                mem_en   <= 1'b1;
                                mem_addr <= (read_addr + read_addr_incr) >> 2;
                                arbif.RDATA <= arbif.mem_rdata;
                            end
                        end else begin
                            arbif.RLAST <= 1'b0;
                            read_state <= R_IDLE;
                        end
                    end
                end

                default: read_state <= R_IDLE;
            endcase
        end
    end
endmodule
