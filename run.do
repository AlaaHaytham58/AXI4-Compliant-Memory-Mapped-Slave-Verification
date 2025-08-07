vlib work
vlog axi_enum.sv axi4.sv axi_constraints.sv axi_memory.sv axi_write_tb.sv axi4_memory_tb.sv Top.sv +cover -covercells
vsim -voptargs=+acc work.Top -cover
coverage exclude -du axi4_memory -togglenode j 
coverage save -onexit cov.ucdb
run -all
coverage report -details -output cov_report.txt
coverage report -details -output -html cov_report.txt
