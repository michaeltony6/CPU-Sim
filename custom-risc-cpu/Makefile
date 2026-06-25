.PHONY: test test-c test-web test-verilog clean

test: test-c test-web test-verilog

test-c:
	$(MAKE) -C c-simulator test

test-web:
	$(MAKE) -C web-debugger test

test-verilog:
	cd verilog && ./tests.sh

clean:
	$(MAKE) -C c-simulator clean
	find verilog -maxdepth 1 \( -name 'cpu_tb' -o -name 'cpu_tb_*' -o -name 'fault_tb' -o -name 'dump.vcd' -o -name 'fault_dump.vcd' \) -delete
