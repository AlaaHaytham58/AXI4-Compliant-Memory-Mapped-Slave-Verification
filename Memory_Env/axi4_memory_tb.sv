`include "../Packages/memory_class.sv";

module axi4_memory_tb  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,  
    parameter MEMORY_DEPTH = 1024
) (
	arb_if.mem_tb arbif
);
    //Signals going from and to DUT
	logic clk, rst_n;
	logic mem_en, mem_we;
    logic [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wdata;
    logic [DATA_WIDTH-1:0] mem_rdata;

    //Inteface Connection
    assign clk = arbif.ACLK;
    assign arbif.ARESETn = rst_n;
    assign arbif.mem_en = mem_en;
    assign arbif.mem_we = mem_we;
    assign arbif.mem_addr = mem_addr;
    assign arbif.mem_wdata = mem_wdata;
    assign mem_rdata = arbif.mem_rdata;

    memory_stim temp;
    memory_stim stim [$];
    memory_cg stim_cg;
    logic [DATA_WIDTH-1:0] expected;
    logic [DATA_WIDTH-1:0] actual;

    //Memory to map data
    reg [DATA_WIDTH-1:0] memory [0:MEMORY_DEPTH-1];

    initial begin
        foreach (memory[i]) begin
            memory[i] = 0;
        end
    end

    initial begin
        stim_cg = new();
        temp = new();

        @(negedge clk);
        rst_n = 0;

        $display("======================== Test 1: testing read/write basic functionality ========================");

        generate_stim(300);


        //writing random data to random adresses
        foreach (stim[i]) begin
            @(negedge clk);
            rst_n = 1;
            mem_en = 1;
            mem_we = 1;
            mem_addr = stim[i].mem_addr;
            mem_wdata = stim[i].mem_wdata;

            //sampling
            sample();

            //writing to our test memory
            memory[mem_addr] = mem_wdata;     
        end


        foreach (stim[i]) begin
            //checking if the read data from the DUT is the same data we wrote
            check_write(stim[i].mem_addr, memory[stim[i].mem_addr],"Test 1: Write");
        end

        $display("======================== Test 2: testing enable functionality ========================");


        foreach (stim[i]) begin
            @(negedge clk);
            mem_en = 0;
            mem_we = 1;

            //turning off enable, keeping the old address but adding different data to the wdata bus
            mem_addr = stim[i].mem_addr;
            mem_wdata = $random();

            //samplig
            sample();

            //checking if the values have changed
            check_write(stim[i].mem_addr, memory[stim[i].mem_addr], "Test 2: Enable");
        end

        $display("======================== Test 3: testing reset functionality ========================");

        generate_stim(300);
        //if the reset is = 0, mem_rdata is set to 0
        // So, we will try to read/write while reset is on, and if any data gets read then the reset does not function correctly,
        //otherwise it -may- function correctly

        @(negedge clk);
        rst_n = 0;

        foreach (stim[i]) begin
            @(negedge clk);
            mem_en = 1;
            mem_we = 1;
            mem_addr = stim[i].mem_addr;
            mem_wdata = stim[i].mem_wdata;

            sample();

            @(negedge clk)
            mem_we = 0;

            sample();

            @(negedge clk)
            if (mem_rdata == 0)
                $display("Test 3 successful, mem_rdata: %h, mem_wdata: %h, test memory content: %h",  mem_rdata, mem_wdata, memory[mem_addr]);
            else
                $error("Test 3 failed, mem_rdata: %h, mem_wdata: %h, test memory content: %h", mem_rdata, mem_wdata, memory[mem_addr]);
        end

        $display("======================== Test 4: Randomization ========================"); 

        stim.shuffle();    

        foreach(stim[i]) begin
            //driving to DUT
            drive_stim(stim[i]);

            //sampling testcase
            sample();

            if (rst_n) 
            begin
                //write to memory if write mode is on
                if ({mem_en, mem_we} == WRITE)
                    memory[mem_addr] = mem_wdata;

                check_write(mem_addr,memory[mem_addr],stim[i].get_mode());
            end
            else
            begin
            //if the reset is on, mem_rdata should read 0
                @(negedge clk);
                if (mem_rdata == 0)
                    $display("%s sucessful,     mem_rdata: %h,      mem_wdata: %h,      test memory: %h", stim[i].get_mode(), mem_rdata, mem_wdata, memory[mem_addr]);
                else
                    $error("%s failed,      mem_rdata: %h,      mem_wdata: %h,      test memory: %h", stim[i].get_mode(), mem_rdata, mem_wdata, memory[mem_addr]);
            end
        end

        #200ns $stop;
    end

    function void generate_stim(int size);
        repeat (size)
        begin
            temp = new();
            temp.randomize();
            stim.push_back(temp);
        end
    endfunction

    task drive_stim(memory_stim st);
            @(negedge clk)
            rst_n = st.rst_n;
            mem_en = st.mem_en;
            mem_we = st.mem_we;
            mem_addr = st.mem_addr;
            mem_wdata = st.mem_wdata;
    endtask

    task check_write(logic [$clog2(MEMORY_DEPTH)-1:0] addr, logic [DATA_WIDTH-1:0] data, string mode);
        @(negedge clk)
        rst_n = 1;
        mem_en = 1;
        mem_we = 0;
        mem_addr = addr;

        @(negedge clk)
        if (mem_rdata == data)
            $display("%s sucessful,     mem_rdata: %h,      mem_wdata: %h,      test memory: %h", mode, mem_rdata, mem_wdata, memory[addr]);
        else
            $error("%s failed,      mem_rdata: %h,      mem_wdata: %h,      test memory: %h", mode, mem_rdata, mem_wdata, memory[addr]);

        //sampling
        sample();
    endtask

    memory_stim sample_stim;
    function void sample();
        sample_stim = new();
        sample_stim.rst_n = rst_n;
        sample_stim.mem_en = mem_en;
        sample_stim.mem_we = mem_we;
        sample_stim.mem_addr = mem_addr;
        sample_stim.mem_wdata = mem_wdata;

        stim_cg.cg.sample(sample_stim);
    endfunction
endmodule