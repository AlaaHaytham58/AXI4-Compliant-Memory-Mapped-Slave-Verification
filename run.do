vlib work 
vlog Packages//axi_enum.sv \
     Packages//axi_constraints.sv \
     Packages//axi_assertions.sv \
     Design//axi4.sv \
     Design//axi_memory.sv \
     AXI_tb//axi4_tb.sv \
     Memory_tb//axi4_memory_tb.sv \
     Top//Interface.sv \
     Top//Top.sv \
     +cover -covercells

vsim -voptargs=+acc work.Top -cover
coverage exclude -du axi4_memory -togglenode j 
coverage save -onexit cov.ucdb
run -all
coverage report -details -output cov_report.txt 


