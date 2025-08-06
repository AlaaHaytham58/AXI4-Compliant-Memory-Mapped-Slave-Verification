vlib work
vlog axi_memory.sv axi4.sv Top.sv axi4_memory_tb.sv +cover -covercells
vsim -voptargs=+acc work.Top -cover
coverage exclude -du axi4_memory -togglenode j 
coverage save -onexit cov.ucdb
run -all
coverage report -details -output cov_report.txt
coverage report -details -output -html cov_report.txt
