vlib work
vlog axi_enum.sv axi_constraints.sv axi_memory.sv axi_write_tb.sv axi4_memory_tb.sv +cover -covercells
vsim -voptargs=+acc work.Top -cover
coverage save -onexit cov.ucdb
run -all
coverage report -details -output cov_report.txt
coverage report -details -output -html cov_report.txt
