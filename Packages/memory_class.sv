     import axi_enum_packet::*;

     class memory_stim;
            rand logic rst_n;
        	rand logic mem_en, mem_we;
            rand logic [9:0] mem_addr;
            rand logic [31:0] mem_wdata;

            constraint rst_n_c 
            {
                rst_n dist {1'b0 := 5, 1'b1 := 95};
            }

            constraint en_c 
            {
                {mem_en, mem_we} dist {OFF := 10, READ := 45, WRITE := 45};
            }

            extern function string get_mode();
    endclass

    function string memory_stim::get_mode();
            if (~rst_n)
                get_mode = "Reset OFF";
            else
                case ({mem_en, mem_we})
                    OFF: get_mode = "Enable off";
                    READ: get_mode = "Read";
                    WRITE: get_mode = "Write";
                    default: get_mode = "Enable off";
                endcase
    endfunction

    class memory_cg;
        covergroup cg with function sample(memory_stim stim);
            rst_cp:         coverpoint stim.rst_n;
            en_cp:          coverpoint stim.mem_en;
            we_cp:          coverpoint stim.mem_we;
            mode_cp:        cross en_cp, we_cp;
            addr_cp:        coverpoint stim.mem_addr;
            wdata_cp:       coverpoint stim.mem_wdata;
            corner_adresses: coverpoint stim.mem_addr
            {
                bins addr_zeros = {10'h000};
                bins addr_ones = {10'h3ff};
                bins addr_zeros_to_ones = (10'h000 => 10'h3ff);
                bins addr_ones_to_zeros = (10'h3ff => 10'h000);
            }
            corner_write: coverpoint stim.mem_wdata
            {
                bins wdata_zeros = {32'h000_0000};
                bins wdata_ones = {32'hffff_ffff};
                bins wdata_zeros_to_ones = (32'h000_0000 => 32'hffff_ffff);
                bins wdata_ones_to_zeros = (32'hffff_ffff => 132'h000_0000);
            }
        endgroup
        cg = new();
    endclass