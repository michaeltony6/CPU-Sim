# Interactive Web Debugger

This static browser app turns the CPU simulator into a visual debugging environment.

Open `index.html` in a browser, or serve this folder locally:

```sh
cd custom-risc-cpu/web-debugger
python3 -m http.server 8000
```

Features:

- Assemble `.asm` source directly in the browser.
- Step, run, pause, and reset execution.
- Toggle breakpoints on instruction addresses.
- Inspect `PC`, step count, halt/fault state, registers, memory, trace output, and machine code.
- Highlight changed registers and memory after each instruction.
- Export newline-separated integer `.bin` machine code.
- Run ISA v2 programs with bitwise operations, shifts, stack/subroutine instructions, signed branches, register-indirect memory, flags, and memory-mapped output.
- Step through a five-stage pipeline model with IF, ID, EX, MEM, WB, data-hazard stalls, branch flushes, and CPI stats.

![Interactive CPU Debugger](../docs/images/web-debugger.png)

Run the JavaScript core tests:

```sh
node tests.js
```
