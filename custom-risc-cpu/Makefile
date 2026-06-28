.PHONY: test test-c test-web test-verilog test-shell clean

test: test-c test-web test-verilog test-shell

test-c:
	$(MAKE) -C c-simulator test

test-web:
	$(MAKE) -C web-debugger test

test-verilog:
	cd verilog && ./tests.sh

test-shell:
	./scripts/language_mix.sh >/dev/null
	./scripts/run_all_examples.sh >/dev/null
	./scripts/debug_isa_v2.sh >/dev/null

clean:
	$(MAKE) -C c-simulator clean
	find verilog -maxdepth 1 \( -name 'cpu_tb' -o -name 'cpu_tb_*' -o -name 'fault_tb' -o -name 'hazard_tb' -o -name 'dump.vcd' -o -name 'fault_dump.vcd' -o -name 'hazard_dump.vcd' \) -delete
