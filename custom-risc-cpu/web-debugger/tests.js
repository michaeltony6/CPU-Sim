"use strict";

const assert = require("assert");
const {
    Cpu,
    EXAMPLES,
    assemble,
    formatInstruction
} = require("./cpu_core");

function runProgram(source) {
    const assembled = assemble(source);
    const cpu = new Cpu(assembled.words);
    const trace = cpu.run();
    return { assembled, cpu, trace };
}

const add = runProgram(EXAMPLES.add_two_numbers);
assert.strictEqual(add.cpu.memory[250], 12);
assert.strictEqual(add.cpu.halted, true);
assert.strictEqual(add.trace.length, 5);
assert.strictEqual(formatInstruction(add.assembled.listing[2]), "ADD R3, R1, R2");

const sum = runProgram(EXAMPLES.sum_1_to_10);
assert.strictEqual(sum.cpu.memory[250], 55);
assert.strictEqual(sum.cpu.halted, true);

const fib = runProgram(EXAMPLES.fibonacci_10_terms);
assert.strictEqual(fib.cpu.memory[250], 88);
assert.strictEqual(fib.cpu.halted, true);

assert.throws(() => assemble("bad-label: HALT"), /invalid label/);
assert.throws(() => assemble("JMP 3"), /invalid branch target/);
assert.throws(() => assemble("MOVI R8, 1"), /invalid register/);

const branchy = assemble(`MOVI R1, 1
loop:
BEQ R1, R1, done
JMP loop
done:
STORE R1, 250
HALT
`);
const cpu = new Cpu(branchy.words);
const event1 = cpu.step();
const event2 = cpu.step();
assert.strictEqual(event1.opcodeName, "MOVI");
assert.strictEqual(event2.opcodeName, "BEQ");
assert.strictEqual(cpu.pc, 12);

console.log("All web debugger CPU core tests passed.");
