(function (root, factory) {
    if (typeof module === "object" && module.exports) {
        module.exports = factory();
    } else {
        root.RiscCpuCore = factory();
    }
}(typeof self !== "undefined" ? self : this, function () {
    "use strict";

    const INSTR_WIDTH = 4;
    const MEMORY_SIZE = 256;
    const NUM_REGISTERS = 8;
    const EXECUTION_LIMIT = 10000;

    const OPCODES = Object.freeze({
        NOP: 0,
        LOAD: 1,
        STORE: 2,
        MOVI: 3,
        ADD: 4,
        SUB: 5,
        JMP: 6,
        BEQ: 7,
        BNE: 8,
        HALT: 9,
        ADDI: 10,
        AND: 11,
        OR: 12,
        XOR: 13,
        SHL: 14,
        SHR: 15,
        LOADR: 16,
        STORER: 17,
        JLT: 18,
        JGT: 19,
        PUSH: 20,
        POP: 21,
        CALL: 22,
        RET: 23
    });

    const OPCODE_NAMES = Object.freeze(Object.fromEntries(
        Object.entries(OPCODES).map(([name, value]) => [value, name])
    ));

    const EXAMPLES = Object.freeze({
        add_two_numbers: `; Compute 5 + 7 and store the result in MEM[250].
MOVI R1, 5
MOVI R2, 7
ADD R3, R1, R2
STORE R3, 250
HALT
`,
        sum_1_to_10: `; Sum integers 1 through 10 and store 55 in MEM[250].
MOVI R1, 1      ; counter
MOVI R2, 10     ; limit
MOVI R3, 0      ; running sum
MOVI R4, 1      ; increment

loop:
ADD R3, R3, R1
BEQ R1, R2, done
ADD R1, R1, R4
JMP loop

done:
STORE R3, 250
HALT
`,
        fibonacci_10_terms: `; Sum the first 10 Fibonacci terms: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34.
; The expected result is 88 in MEM[250].
MOVI R1, 0      ; current Fibonacci term
MOVI R2, 1      ; next Fibonacci term
MOVI R3, 0      ; running sum
MOVI R4, 10     ; remaining terms
MOVI R5, 0      ; zero constant
MOVI R6, 1      ; decrement value

loop:
BEQ R4, R5, done
ADD R3, R3, R1
ADD R7, R1, R2
MOVI R1, 0
ADD R1, R1, R2
MOVI R2, 0
ADD R2, R2, R7
SUB R4, R4, R6
JMP loop

done:
STORE R3, 250
HALT
`,
        isa_v2_demo: `; ISA v2 demo.
; Expected result: MEM[250] = 20.

MOVI R7, 256
MOVI R1, 5
ADDI R2, R1, 3
MOVI R3, 6
AND R4, R2, R3
OR R4, R2, R3
XOR R4, R4, R3
SHL R5, R1, 2
SHR R6, R5, 1

MOVI R0, 240
STORER R6, R0
LOADR R3, R0

PUSH R3
MOVI R3, 0
POP R4
CALL double

MOVI R5, 25
JLT R4, R5, less_ok
MOVI R4, 0

less_ok:
JGT R4, R3, greater_ok
MOVI R4, 0

greater_ok:
MOVI R6, 255
STORER R4, R6
STORE R4, 250
HALT

double:
ADD R4, R4, R4
RET
`
    });

    class AssemblyError extends Error {
        constructor(lineNumber, message) {
            super(lineNumber ? `line ${lineNumber}: ${message}` : message);
            this.name = "AssemblyError";
            this.lineNumber = lineNumber;
        }
    }

    class RuntimeError extends Error {
        constructor(pc, message) {
            super(`PC ${pc}: ${message}`);
            this.name = "RuntimeError";
            this.pc = pc;
        }
    }

    function stripComment(line) {
        const commentIndex = line.indexOf(";");
        return (commentIndex >= 0 ? line.slice(0, commentIndex) : line).trim();
    }

    function tokenize(line) {
        return line.split(/[\s,]+/).filter(Boolean);
    }

    function parseInteger(text, lineNumber, description) {
        if (!/^[+-]?(?:0x[0-9a-fA-F]+|\d+)$/.test(text)) {
            throw new AssemblyError(lineNumber, `invalid ${description} '${text}'`);
        }
        const value = Number.parseInt(text, 0);
        if (!Number.isSafeInteger(value)) {
            throw new AssemblyError(lineNumber, `invalid ${description} '${text}'`);
        }
        return value;
    }

    function validateRegisterNumber(reg, lineNumber, text) {
        if (!Number.isInteger(reg) || reg < 0 || reg >= NUM_REGISTERS) {
            throw new AssemblyError(lineNumber, `invalid register '${text}'`);
        }
    }

    function parseRegister(text, lineNumber) {
        const match = /^R(\d+)$/i.exec(text);
        if (!match) {
            throw new AssemblyError(lineNumber, `invalid register '${text}'`);
        }
        const reg = Number.parseInt(match[1], 10);
        validateRegisterNumber(reg, lineNumber, text);
        return reg;
    }

    function validateAddress(addr, lineNumber) {
        if (!Number.isInteger(addr) || addr < 0 || addr >= MEMORY_SIZE) {
            throw new AssemblyError(lineNumber, `invalid memory address '${addr}'`);
        }
    }

    function validateTarget(target, lineNumber) {
        if (!Number.isInteger(target) || target < 0 || target > MEMORY_SIZE - INSTR_WIDTH || target % INSTR_WIDTH !== 0) {
            throw new AssemblyError(
                lineNumber,
                `invalid branch target ${target} (must be 0-${MEMORY_SIZE - INSTR_WIDTH} and divisible by ${INSTR_WIDTH})`
            );
        }
    }

    function validateShiftAmount(amount, lineNumber) {
        if (!Number.isInteger(amount) || amount < 0 || amount > 31) {
            throw new AssemblyError(lineNumber, `invalid shift amount ${amount} (must be 0-31)`);
        }
    }

    function validateLabel(name, lineNumber) {
        if (!name) {
            throw new AssemblyError(lineNumber, "empty label");
        }
        if (name.length > 63) {
            throw new AssemblyError(lineNumber, `label '${name}' is too long (max 63 characters)`);
        }
        if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) {
            throw new AssemblyError(
                lineNumber,
                `invalid label '${name}' (use letters, numbers, and underscores; do not start with a number)`
            );
        }
    }

    function expectedOperands(opcodeName) {
        switch (opcodeName) {
        case "NOP":
        case "HALT":
        case "RET":
            return 0;
        case "JMP":
        case "CALL":
        case "PUSH":
        case "POP":
            return 1;
        case "LOAD":
        case "STORE":
        case "MOVI":
        case "LOADR":
        case "STORER":
            return 2;
        case "ADD":
        case "SUB":
        case "BEQ":
        case "BNE":
        case "ADDI":
        case "AND":
        case "OR":
        case "XOR":
        case "SHL":
        case "SHR":
        case "JLT":
        case "JGT":
            return 3;
        default:
            return -1;
        }
    }

    function parseLines(source) {
        return source.split(/\r?\n/).map((raw, index) => ({
            raw,
            lineNumber: index + 1,
            clean: stripComment(raw)
        }));
    }

    function splitLabel(clean, lineNumber) {
        const colonIndex = clean.indexOf(":");
        if (colonIndex < 0) {
            return { label: null, rest: clean };
        }
        const label = clean.slice(0, colonIndex).trim();
        validateLabel(label, lineNumber);
        return { label, rest: clean.slice(colonIndex + 1).trim() };
    }

    function resolveTarget(text, labels, lineNumber) {
        if (labels.has(text)) {
            const target = labels.get(text);
            validateTarget(target, lineNumber);
            return target;
        }
        const target = parseInteger(text, lineNumber, "branch target");
        validateTarget(target, lineNumber);
        return target;
    }

    function assemble(source) {
        const labels = new Map();
        const lines = parseLines(source);
        let address = 0;

        for (const line of lines) {
            if (!line.clean) {
                continue;
            }
            const { label, rest } = splitLabel(line.clean, line.lineNumber);
            if (label) {
                if (labels.has(label)) {
                    throw new AssemblyError(line.lineNumber, `duplicate label '${label}'`);
                }
                labels.set(label, address);
            }
            if (rest) {
                address += INSTR_WIDTH;
                if (address > MEMORY_SIZE) {
                    throw new AssemblyError(line.lineNumber, `program exceeds ${MEMORY_SIZE}-word memory`);
                }
            }
        }

        const words = [];
        const listing = [];
        address = 0;

        for (const line of lines) {
            if (!line.clean) {
                continue;
            }
            const { rest } = splitLabel(line.clean, line.lineNumber);
            if (!rest) {
                continue;
            }

            const tokens = tokenize(rest);
            const mnemonic = tokens[0].toUpperCase();
            if (!(mnemonic in OPCODES)) {
                throw new AssemblyError(line.lineNumber, `unknown opcode '${tokens[0]}'`);
            }

            const expected = expectedOperands(mnemonic);
            const got = tokens.length - 1;
            if (got !== expected) {
                throw new AssemblyError(line.lineNumber, `${mnemonic} expects ${expected} operand(s), got ${got}`);
            }

            let a = 0;
            let b = 0;
            let c = 0;

            switch (mnemonic) {
            case "LOAD":
            case "STORE":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseInteger(tokens[2], line.lineNumber, "memory address");
                validateAddress(b, line.lineNumber);
                break;
            case "MOVI":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseInteger(tokens[2], line.lineNumber, "immediate");
                break;
            case "ADD":
            case "SUB":
            case "AND":
            case "OR":
            case "XOR":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseRegister(tokens[2], line.lineNumber);
                c = parseRegister(tokens[3], line.lineNumber);
                break;
            case "ADDI":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseRegister(tokens[2], line.lineNumber);
                c = parseInteger(tokens[3], line.lineNumber, "immediate");
                break;
            case "SHL":
            case "SHR":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseRegister(tokens[2], line.lineNumber);
                c = parseInteger(tokens[3], line.lineNumber, "shift amount");
                validateShiftAmount(c, line.lineNumber);
                break;
            case "LOADR":
            case "STORER":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseRegister(tokens[2], line.lineNumber);
                break;
            case "JMP":
            case "CALL":
                a = resolveTarget(tokens[1], labels, line.lineNumber);
                break;
            case "BEQ":
            case "BNE":
            case "JLT":
            case "JGT":
                a = parseRegister(tokens[1], line.lineNumber);
                b = parseRegister(tokens[2], line.lineNumber);
                c = resolveTarget(tokens[3], labels, line.lineNumber);
                break;
            case "PUSH":
            case "POP":
                a = parseRegister(tokens[1], line.lineNumber);
                break;
            default:
                break;
            }

            const instruction = [OPCODES[mnemonic], a, b, c];
            words.push(...instruction);
            listing.push({
                address,
                lineNumber: line.lineNumber,
                source: line.raw.trim(),
                mnemonic,
                operands: [a, b, c],
                words: instruction
            });
            address += INSTR_WIDTH;
        }

        if (words.length === 0) {
            throw new AssemblyError(0, "program has no instructions");
        }

        return { words, listing, labels };
    }

    function opcodeName(opcode) {
        return OPCODE_NAMES[opcode] || `UNKNOWN(${opcode})`;
    }

    function cloneArray(values) {
        return values.slice();
    }

    class Cpu {
        constructor(words) {
            this.originalWords = cloneArray(words);
            this.reset();
        }

        reset() {
            this.memory = new Array(MEMORY_SIZE).fill(0);
            for (let i = 0; i < this.originalWords.length; i += 1) {
                this.memory[i] = this.originalWords[i];
            }
            this.registers = new Array(NUM_REGISTERS).fill(0);
            this.registers[7] = MEMORY_SIZE;
            this.flags = { zero: false, negative: false, carry: false };
            this.output = [];
            this.pc = 0;
            this.steps = 0;
            this.halted = false;
            this.fault = null;
            this.lastChanges = { registers: [], memory: [] };
        }

        requireRegister(reg) {
            if (!Number.isInteger(reg) || reg < 0 || reg >= NUM_REGISTERS) {
                throw new RuntimeError(this.pc, `invalid register R${reg}`);
            }
        }

        requireAddress(addr) {
            if (!Number.isInteger(addr) || addr < 0 || addr >= MEMORY_SIZE) {
                throw new RuntimeError(this.pc, `invalid memory address ${addr}`);
            }
        }

        requireTarget(target) {
            if (!Number.isInteger(target) || target < 0 || target > MEMORY_SIZE - INSTR_WIDTH || target % INSTR_WIDTH !== 0) {
                throw new RuntimeError(this.pc, `invalid branch target ${target}`);
            }
        }

        requireShiftAmount(amount) {
            if (!Number.isInteger(amount) || amount < 0 || amount > 31) {
                throw new RuntimeError(this.pc, `invalid shift amount ${amount}`);
            }
        }

        updateFlags(value, carry = false) {
            this.flags = {
                zero: value === 0,
                negative: value < 0,
                carry
            };
        }

        writeRegister(reg, value, carry = false) {
            this.registers[reg] = value | 0;
            this.updateFlags(this.registers[reg], carry);
        }

        writeMemory(addr, value) {
            this.memory[addr] = value | 0;
            if (addr === 255) {
                this.output.push(this.memory[addr]);
            }
        }

        pushValue(value) {
            const nextSp = this.registers[7] - 1;
            this.requireAddress(nextSp);
            this.registers[7] = nextSp;
            this.memory[nextSp] = value | 0;
        }

        popValue() {
            const sp = this.registers[7];
            this.requireAddress(sp);
            const value = this.memory[sp];
            this.registers[7] = sp + 1;
            return value;
        }

        fetch() {
            if (this.pc < 0 || this.pc > MEMORY_SIZE - INSTR_WIDTH || this.pc % INSTR_WIDTH !== 0) {
                throw new RuntimeError(this.pc, `PC out of bounds or misaligned`);
            }
            return {
                pc: this.pc,
                opcode: this.memory[this.pc],
                a: this.memory[this.pc + 1],
                b: this.memory[this.pc + 2],
                c: this.memory[this.pc + 3]
            };
        }

        step() {
            if (this.halted) {
                return {
                    halted: true,
                    pc: this.pc,
                    opcode: OPCODES.HALT,
                    opcodeName: "HALT",
                    changes: this.lastChanges
                };
            }
            if (this.steps >= EXECUTION_LIMIT) {
                throw new RuntimeError(this.pc, `execution limit of ${EXECUTION_LIMIT} steps reached`);
            }

            const beforeRegisters = cloneArray(this.registers);
            const beforeMemory = cloneArray(this.memory);
            const instr = this.fetch();
            let nextPc = this.pc + INSTR_WIDTH;

            switch (instr.opcode) {
            case OPCODES.NOP:
                break;
            case OPCODES.LOAD:
                this.requireRegister(instr.a);
                this.requireAddress(instr.b);
                this.writeRegister(instr.a, this.memory[instr.b]);
                break;
            case OPCODES.STORE:
                this.requireRegister(instr.a);
                this.requireAddress(instr.b);
                this.writeMemory(instr.b, this.registers[instr.a]);
                break;
            case OPCODES.MOVI:
                this.requireRegister(instr.a);
                this.writeRegister(instr.a, instr.b);
                break;
            case OPCODES.ADD:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireRegister(instr.c);
                {
                    const result = this.registers[instr.b] + this.registers[instr.c];
                    this.writeRegister(instr.a, result, result > 2147483647 || result < -2147483648);
                }
                break;
            case OPCODES.SUB:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireRegister(instr.c);
                {
                    const result = this.registers[instr.b] - this.registers[instr.c];
                    this.writeRegister(instr.a, result, result > 2147483647 || result < -2147483648);
                }
                break;
            case OPCODES.JMP:
                this.requireTarget(instr.a);
                nextPc = instr.a;
                break;
            case OPCODES.BEQ:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireTarget(instr.c);
                if (this.registers[instr.a] === this.registers[instr.b]) {
                    nextPc = instr.c;
                }
                break;
            case OPCODES.BNE:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireTarget(instr.c);
                if (this.registers[instr.a] !== this.registers[instr.b]) {
                    nextPc = instr.c;
                }
                break;
            case OPCODES.HALT:
                this.halted = true;
                break;
            case OPCODES.ADDI:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                {
                    const result = this.registers[instr.b] + instr.c;
                    this.writeRegister(instr.a, result, result > 2147483647 || result < -2147483648);
                }
                break;
            case OPCODES.AND:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireRegister(instr.c);
                this.writeRegister(instr.a, this.registers[instr.b] & this.registers[instr.c]);
                break;
            case OPCODES.OR:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireRegister(instr.c);
                this.writeRegister(instr.a, this.registers[instr.b] | this.registers[instr.c]);
                break;
            case OPCODES.XOR:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireRegister(instr.c);
                this.writeRegister(instr.a, this.registers[instr.b] ^ this.registers[instr.c]);
                break;
            case OPCODES.SHL:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireShiftAmount(instr.c);
                this.writeRegister(instr.a, this.registers[instr.b] << instr.c, instr.c !== 0 && ((this.registers[instr.b] >>> (32 - instr.c)) !== 0));
                break;
            case OPCODES.SHR:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireShiftAmount(instr.c);
                this.writeRegister(instr.a, this.registers[instr.b] >>> instr.c);
                break;
            case OPCODES.LOADR:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireAddress(this.registers[instr.b]);
                this.writeRegister(instr.a, this.memory[this.registers[instr.b]]);
                break;
            case OPCODES.STORER:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireAddress(this.registers[instr.b]);
                this.writeMemory(this.registers[instr.b], this.registers[instr.a]);
                break;
            case OPCODES.JLT:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireTarget(instr.c);
                if (this.registers[instr.a] < this.registers[instr.b]) {
                    nextPc = instr.c;
                }
                break;
            case OPCODES.JGT:
                this.requireRegister(instr.a);
                this.requireRegister(instr.b);
                this.requireTarget(instr.c);
                if (this.registers[instr.a] > this.registers[instr.b]) {
                    nextPc = instr.c;
                }
                break;
            case OPCODES.PUSH:
                this.requireRegister(instr.a);
                this.pushValue(this.registers[instr.a]);
                break;
            case OPCODES.POP:
                this.requireRegister(instr.a);
                this.writeRegister(instr.a, this.popValue());
                break;
            case OPCODES.CALL:
                this.requireTarget(instr.a);
                this.pushValue(nextPc);
                nextPc = instr.a;
                break;
            case OPCODES.RET:
                nextPc = this.popValue();
                this.requireTarget(nextPc);
                break;
            default:
                throw new RuntimeError(this.pc, `unknown opcode ${instr.opcode}`);
            }

            this.pc = nextPc;
            this.steps += 1;
            this.lastChanges = diffState(beforeRegisters, this.registers, beforeMemory, this.memory);

            return {
                ...instr,
                opcodeName: opcodeName(instr.opcode),
                nextPc,
                halted: this.halted,
                steps: this.steps,
                changes: this.lastChanges
            };
        }

        run(options = {}) {
            const breakpoints = options.breakpoints || new Set();
            const maxSteps = options.maxSteps || EXECUTION_LIMIT;
            const events = [];

            while (!this.halted && events.length < maxSteps) {
                if (events.length > 0 && breakpoints.has(this.pc)) {
                    break;
                }
                const event = this.step();
                events.push(event);
                if (!this.halted && breakpoints.has(this.pc)) {
                    break;
                }
            }

            return events;
        }
    }

    function instructionReads(words) {
        const [opcode, a, b] = words;
        switch (opcodeName(opcode)) {
        case "STORE":
            return [a];
        case "ADD":
        case "SUB":
        case "AND":
        case "OR":
        case "XOR":
        case "BEQ":
        case "BNE":
        case "JLT":
        case "JGT":
            return [a, b];
        case "ADDI":
        case "SHL":
        case "SHR":
        case "LOADR":
            return [b];
        case "STORER":
            return [a, b];
        case "PUSH":
            return [a, 7];
        case "POP":
        case "RET":
        case "CALL":
            return [7];
        default:
            return [];
        }
    }

    function instructionWrites(words) {
        const [opcode, a] = words;
        switch (opcodeName(opcode)) {
        case "LOAD":
        case "MOVI":
        case "ADD":
        case "SUB":
        case "ADDI":
        case "AND":
        case "OR":
        case "XOR":
        case "SHL":
        case "SHR":
        case "LOADR":
            return [a];
        case "PUSH":
        case "CALL":
        case "RET":
            return [7];
        case "POP":
            return [a, 7];
        default:
            return [];
        }
    }

    function stageLabel(entry) {
        if (!entry) {
            return "-";
        }
        if (entry.bubble) {
            return "STALL";
        }
        return `${entry.address}: ${formatInstruction(entry.listing)}`;
    }

    class PipelineCpu {
        constructor(assembled) {
            this.assembled = assembled;
            this.listingByAddress = new Map(assembled.listing.map((item) => [item.address, item]));
            this.cpu = new Cpu(assembled.words);
            this.reset();
        }

        reset() {
            this.cpu = new Cpu(this.assembled.words);
            this.fetchPc = 0;
            this.fetchStopped = false;
            this.cycle = 0;
            this.stalls = 0;
            this.flushes = 0;
            this.history = [];
            this.stages = {
                IF: null,
                ID: null,
                EX: null,
                MEM: null,
                WB: null
            };
        }

        isDone() {
            return this.fetchStopped &&
                !this.stages.IF &&
                !this.stages.ID &&
                !this.stages.EX &&
                !this.stages.MEM &&
                !this.stages.WB;
        }

        makeEntry(address) {
            const listing = this.listingByAddress.get(address);
            if (!listing) {
                throw new RuntimeError(address, "pipeline fetch reached non-instruction memory");
            }
            return {
                address,
                listing,
                words: listing.words,
                reads: instructionReads(listing.words),
                writes: instructionWrites(listing.words),
                executed: false,
                bubble: false
            };
        }

        fetchEntry() {
            if (this.fetchStopped) {
                return null;
            }
            if (this.fetchPc < 0 || this.fetchPc > MEMORY_SIZE - INSTR_WIDTH || this.fetchPc % INSTR_WIDTH !== 0) {
                throw new RuntimeError(this.fetchPc, "pipeline PC out of bounds or misaligned");
            }
            if (!this.listingByAddress.has(this.fetchPc)) {
                this.fetchStopped = true;
                return null;
            }
            const entry = this.makeEntry(this.fetchPc);
            this.fetchPc += INSTR_WIDTH;
            return entry;
        }

        hasDataHazard() {
            const id = this.stages.ID;
            if (!id || id.bubble || id.reads.length === 0) {
                return false;
            }
            const pendingWrites = [
                ...(this.stages.EX && !this.stages.EX.bubble ? this.stages.EX.writes : []),
                ...(this.stages.MEM && !this.stages.MEM.bubble ? this.stages.MEM.writes : [])
            ];
            return id.reads.some((reg) => pendingWrites.includes(reg));
        }

        executeExStage() {
            const ex = this.stages.EX;
            if (!ex || ex.bubble || ex.executed) {
                return null;
            }
            if (this.cpu.pc !== ex.address) {
                throw new RuntimeError(ex.address, `pipeline/reference PC mismatch, expected ${this.cpu.pc}`);
            }
            const event = this.cpu.step();
            ex.executed = true;
            const sequentialNext = ex.address + INSTR_WIDTH;
            const controlChangedPc = event.nextPc !== sequentialNext && !event.halted;
            if (controlChangedPc) {
                const flushed = Number(Boolean(this.stages.IF)) + Number(Boolean(this.stages.ID));
                this.flushes += flushed;
                this.stages.IF = null;
                this.stages.ID = null;
                this.fetchPc = event.nextPc;
            }
            if (event.halted) {
                this.fetchStopped = true;
                this.stages.IF = null;
                this.stages.ID = null;
            }
            return { event, controlChangedPc };
        }

        stepCycle() {
            if (this.isDone()) {
                return this.history.at(-1) || null;
            }

            this.cycle += 1;
            const execution = this.executeExStage();
            const hazard = !execution?.controlChangedPc && !this.fetchStopped && this.hasDataHazard();
            if (hazard) {
                this.stalls += 1;
            }

            const next = {
                WB: this.stages.MEM,
                MEM: this.stages.EX,
                EX: hazard ? { bubble: true } : this.stages.ID,
                ID: hazard ? this.stages.ID : this.stages.IF,
                IF: hazard ? this.stages.IF : this.fetchEntry()
            };
            this.stages = next;

            const row = {
                cycle: this.cycle,
                IF: stageLabel(this.stages.IF),
                ID: stageLabel(this.stages.ID),
                EX: stageLabel(this.stages.EX),
                MEM: stageLabel(this.stages.MEM),
                WB: stageLabel(this.stages.WB),
                event: execution?.event || null,
                stalled: hazard,
                flushed: execution?.controlChangedPc || false,
                pc: this.cpu.pc,
                halted: this.isDone()
            };
            this.history.push(row);
            return row;
        }

        runUntilDone(maxCycles = EXECUTION_LIMIT) {
            const rows = [];
            while (!this.isDone() && rows.length < maxCycles) {
                rows.push(this.stepCycle());
            }
            return rows;
        }

        stats() {
            const retired = this.cpu.steps;
            return {
                cycles: this.cycle,
                retired,
                stalls: this.stalls,
                flushes: this.flushes,
                cpi: retired > 0 ? this.cycle / retired : 0
            };
        }
    }

    function diffState(beforeRegisters, afterRegisters, beforeMemory, afterMemory) {
        const registers = [];
        const memory = [];
        for (let i = 0; i < beforeRegisters.length; i += 1) {
            if (beforeRegisters[i] !== afterRegisters[i]) {
                registers.push(i);
            }
        }
        for (let i = 0; i < beforeMemory.length; i += 1) {
            if (beforeMemory[i] !== afterMemory[i]) {
                memory.push(i);
            }
        }
        return { registers, memory };
    }

    function formatInstruction(item) {
        const [opcode, a, b, c] = item.words;
        const name = opcodeName(opcode);
        switch (name) {
        case "NOP":
        case "HALT":
        case "RET":
            return name;
        case "LOAD":
            return `LOAD R${a}, ${b}`;
        case "STORE":
            return `STORE R${a}, ${b}`;
        case "MOVI":
            return `MOVI R${a}, ${b}`;
        case "ADD":
            return `ADD R${a}, R${b}, R${c}`;
        case "SUB":
            return `SUB R${a}, R${b}, R${c}`;
        case "JMP":
            return `JMP ${a}`;
        case "BEQ":
            return `BEQ R${a}, R${b}, ${c}`;
        case "BNE":
            return `BNE R${a}, R${b}, ${c}`;
        case "ADDI":
            return `ADDI R${a}, R${b}, ${c}`;
        case "AND":
            return `AND R${a}, R${b}, R${c}`;
        case "OR":
            return `OR R${a}, R${b}, R${c}`;
        case "XOR":
            return `XOR R${a}, R${b}, R${c}`;
        case "SHL":
            return `SHL R${a}, R${b}, ${c}`;
        case "SHR":
            return `SHR R${a}, R${b}, ${c}`;
        case "LOADR":
            return `LOADR R${a}, R${b}`;
        case "STORER":
            return `STORER R${a}, R${b}`;
        case "JLT":
            return `JLT R${a}, R${b}, ${c}`;
        case "JGT":
            return `JGT R${a}, R${b}, ${c}`;
        case "PUSH":
            return `PUSH R${a}`;
        case "POP":
            return `POP R${a}`;
        case "CALL":
            return `CALL ${a}`;
        default:
            return `${name} ${a}, ${b}, ${c}`;
        }
    }

    return {
        INSTR_WIDTH,
        MEMORY_SIZE,
        NUM_REGISTERS,
        EXECUTION_LIMIT,
        OPCODES,
        OPCODE_NAMES,
        EXAMPLES,
        AssemblyError,
        RuntimeError,
        Cpu,
        PipelineCpu,
        assemble,
        formatInstruction,
        opcodeName
    };
}));
