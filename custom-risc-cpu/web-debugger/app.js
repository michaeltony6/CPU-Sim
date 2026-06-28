"use strict";

const {
    Cpu,
    EXAMPLES,
    MEMORY_SIZE,
    NUM_REGISTERS,
    PipelineCpu,
    assemble,
    formatInstruction,
    opcodeName
} = window.RiscCpuCore;

const state = {
    assembled: null,
    cpu: null,
    pipeline: null,
    trace: [],
    breakpoints: new Set(),
    runTimer: null,
    pipelineTimer: null
};

const els = {
    exampleSelect: document.querySelector("#exampleSelect"),
    sourceEditor: document.querySelector("#sourceEditor"),
    assembleBtn: document.querySelector("#assembleBtn"),
    resetBtn: document.querySelector("#resetBtn"),
    stepBtn: document.querySelector("#stepBtn"),
    runBtn: document.querySelector("#runBtn"),
    pauseBtn: document.querySelector("#pauseBtn"),
    pipelineCycleBtn: document.querySelector("#pipelineCycleBtn"),
    pipelineRunBtn: document.querySelector("#pipelineRunBtn"),
    exportBtn: document.querySelector("#exportBtn"),
    statusText: document.querySelector("#statusText"),
    pcValue: document.querySelector("#pcValue"),
    stepValue: document.querySelector("#stepValue"),
    haltValue: document.querySelector("#haltValue"),
    flagsValue: document.querySelector("#flagsValue"),
    resultValue: document.querySelector("#resultValue"),
    outputValue: document.querySelector("#outputValue"),
    registerGrid: document.querySelector("#registerGrid"),
    memoryGrid: document.querySelector("#memoryGrid"),
    listingBody: document.querySelector("#listingBody"),
    pipeCyclesValue: document.querySelector("#pipeCyclesValue"),
    pipeRetiredValue: document.querySelector("#pipeRetiredValue"),
    pipeStallsValue: document.querySelector("#pipeStallsValue"),
    pipeFlushesValue: document.querySelector("#pipeFlushesValue"),
    pipeCpiValue: document.querySelector("#pipeCpiValue"),
    pipelineStages: document.querySelector("#pipelineStages"),
    pipelineHistoryBody: document.querySelector("#pipelineHistoryBody"),
    traceLog: document.querySelector("#traceLog"),
    machineCode: document.querySelector("#machineCode")
};

function init() {
    for (const name of Object.keys(EXAMPLES)) {
        const option = document.createElement("option");
        option.value = name;
        option.textContent = name.replaceAll("_", " ");
        els.exampleSelect.appendChild(option);
    }

    els.exampleSelect.value = "add_two_numbers";
    els.sourceEditor.value = EXAMPLES.add_two_numbers;

    els.exampleSelect.addEventListener("change", () => {
        els.sourceEditor.value = EXAMPLES[els.exampleSelect.value];
        assembleProgram();
    });
    els.assembleBtn.addEventListener("click", assembleProgram);
    els.resetBtn.addEventListener("click", resetCpu);
    els.stepBtn.addEventListener("click", stepCpu);
    els.runBtn.addEventListener("click", runCpu);
    els.pauseBtn.addEventListener("click", pauseCpu);
    els.pipelineCycleBtn.addEventListener("click", stepPipeline);
    els.pipelineRunBtn.addEventListener("click", runPipeline);
    els.exportBtn.addEventListener("click", exportMachineCode);

    renderEmptyState();
    assembleProgram();
}

function setStatus(message, kind = "ok") {
    els.statusText.textContent = message;
    els.statusText.dataset.kind = kind;
}

function assembleProgram() {
    pauseCpu();
    state.breakpoints.clear();
    try {
        state.assembled = assemble(els.sourceEditor.value);
        state.cpu = new Cpu(state.assembled.words);
        state.pipeline = new PipelineCpu(state.assembled);
        state.trace = [];
        els.machineCode.value = state.assembled.words.join("\n");
        setStatus(`Assembled ${state.assembled.listing.length} instruction(s).`, "ok");
        renderAll();
    } catch (error) {
        state.assembled = null;
        state.cpu = null;
        state.pipeline = null;
        state.trace = [];
        els.machineCode.value = "";
        setStatus(error.message, "error");
        renderEmptyState();
    }
}

function resetCpu() {
    pauseCpu();
    if (!state.assembled) {
        assembleProgram();
        return;
    }
    state.cpu = new Cpu(state.assembled.words);
    state.pipeline = new PipelineCpu(state.assembled);
    state.trace = [];
    setStatus("CPU reset.", "ok");
    renderAll();
}

function stepCpu() {
    if (!state.cpu) {
        assembleProgram();
        return;
    }
    if (state.cpu.halted) {
        setStatus("Program is halted. Reset to run again.", "warn");
        return;
    }

    try {
        const event = state.cpu.step();
        state.trace.unshift(event);
        setStatus(`${event.opcodeName} executed at PC ${event.pc}.`, event.halted ? "warn" : "ok");
        renderAll();
    } catch (error) {
        pauseCpu();
        state.cpu.halted = true;
        state.cpu.fault = error.message;
        setStatus(error.message, "error");
        renderAll();
    }
}

function runCpu() {
    if (!state.cpu) {
        assembleProgram();
        return;
    }
    if (state.cpu.halted) {
        setStatus("Program is halted. Reset to run again.", "warn");
        return;
    }
    if (state.runTimer) {
        return;
    }

    setStatus("Running.", "ok");
    state.runTimer = window.setInterval(() => {
        if (!state.cpu || state.cpu.halted) {
            pauseCpu();
            renderAll();
            return;
        }
        if (state.breakpoints.has(state.cpu.pc)) {
            pauseCpu();
            setStatus(`Paused at breakpoint PC ${state.cpu.pc}.`, "warn");
            renderAll();
            return;
        }
        stepCpu();
    }, 180);
}

function pauseCpu() {
    if (state.runTimer) {
        window.clearInterval(state.runTimer);
        state.runTimer = null;
    }
    if (state.pipelineTimer) {
        window.clearInterval(state.pipelineTimer);
        state.pipelineTimer = null;
    }
}

function stepPipeline() {
    if (!state.pipeline) {
        assembleProgram();
        return;
    }
    if (state.pipeline.isDone()) {
        setStatus("Pipeline is drained. Reset to run again.", "warn");
        return;
    }

    try {
        const row = state.pipeline.stepCycle();
        setStatus(`Pipeline cycle ${row.cycle} completed.`, row.stalled || row.flushed ? "warn" : "ok");
        renderPipeline();
    } catch (error) {
        pauseCpu();
        setStatus(error.message, "error");
        renderPipeline();
    }
}

function runPipeline() {
    if (!state.pipeline) {
        assembleProgram();
        return;
    }
    if (state.pipeline.isDone()) {
        setStatus("Pipeline is drained. Reset to run again.", "warn");
        return;
    }
    if (state.pipelineTimer) {
        return;
    }

    setStatus("Pipeline running.", "ok");
    state.pipelineTimer = window.setInterval(() => {
        if (!state.pipeline || state.pipeline.isDone()) {
            pauseCpu();
            renderPipeline();
            return;
        }
        stepPipeline();
    }, 220);
}

function exportMachineCode() {
    if (!state.assembled) {
        assembleProgram();
        if (!state.assembled) {
            return;
        }
    }

    const blob = new Blob([state.assembled.words.join("\n") + "\n"], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${els.exampleSelect.value || "program"}.bin`;
    link.click();
    URL.revokeObjectURL(url);
}

function renderAll() {
    renderStats();
    renderRegisters();
    renderMemory();
    renderListing();
    renderPipeline();
    renderTrace();
}

function renderEmptyState() {
    els.pcValue.textContent = "--";
    els.stepValue.textContent = "--";
    els.haltValue.textContent = "--";
    els.flagsValue.textContent = "--";
    els.resultValue.textContent = "--";
    els.outputValue.textContent = "--";
    els.registerGrid.innerHTML = "";
    els.memoryGrid.innerHTML = "";
    els.listingBody.innerHTML = "";
    els.pipeCyclesValue.textContent = "--";
    els.pipeRetiredValue.textContent = "--";
    els.pipeStallsValue.textContent = "--";
    els.pipeFlushesValue.textContent = "--";
    els.pipeCpiValue.textContent = "--";
    els.pipelineStages.innerHTML = "";
    els.pipelineHistoryBody.innerHTML = "";
    els.traceLog.innerHTML = "";
}

function renderPipeline() {
    const pipeline = state.pipeline;
    if (!pipeline) {
        return;
    }
    const stats = pipeline.stats();
    els.pipeCyclesValue.textContent = stats.cycles;
    els.pipeRetiredValue.textContent = stats.retired;
    els.pipeStallsValue.textContent = stats.stalls;
    els.pipeFlushesValue.textContent = stats.flushes;
    els.pipeCpiValue.textContent = stats.retired > 0 ? stats.cpi.toFixed(2) : "--";

    els.pipelineStages.innerHTML = "";
    for (const stage of ["IF", "ID", "EX", "MEM", "WB"]) {
        const tile = document.createElement("div");
        const entry = pipeline.stages[stage];
        tile.className = `pipeline-stage${entry?.bubble ? " bubble" : ""}`;
        tile.innerHTML = `<span>${stage}</span><strong>${entry ? pipelineStageText(entry) : "-"}</strong>`;
        els.pipelineStages.appendChild(tile);
    }

    els.pipelineHistoryBody.innerHTML = "";
    for (const row of pipeline.history.slice(-40).reverse()) {
        const tr = document.createElement("tr");
        const note = [
            row.stalled ? "data stall" : "",
            row.flushed ? "branch flush" : ""
        ].filter(Boolean).join(", ");
        tr.className = `${row.stalled ? "pipeline-stall-row" : ""} ${row.flushed ? "pipeline-flush-row" : ""}`;
        tr.innerHTML = `
            <td>${row.cycle}</td>
            <td>${row.IF}</td>
            <td>${row.ID}</td>
            <td>${row.EX}</td>
            <td>${row.MEM}</td>
            <td>${row.WB}</td>
            <td>${note || "-"}</td>
        `;
        els.pipelineHistoryBody.appendChild(tr);
    }
}

function pipelineStageText(entry) {
    if (!entry) {
        return "-";
    }
    if (entry.bubble) {
        return "STALL";
    }
    return `${entry.address}: ${formatInstruction(entry.listing)}`;
}

function renderStats() {
    const cpu = state.cpu;
    els.pcValue.textContent = cpu.pc;
    els.stepValue.textContent = cpu.steps;
    els.haltValue.textContent = cpu.fault ? "FAULT" : (cpu.halted ? "HALT" : "RUN");
    els.flagsValue.textContent = `Z${Number(cpu.flags.zero)} N${Number(cpu.flags.negative)} C${Number(cpu.flags.carry)}`;
    els.resultValue.textContent = cpu.memory[250];
    els.outputValue.textContent = cpu.output.length > 0 ? cpu.output.at(-1) : "--";
}

function renderRegisters() {
    const cpu = state.cpu;
    const changed = new Set(cpu.lastChanges.registers);
    els.registerGrid.innerHTML = "";
    for (let i = 0; i < NUM_REGISTERS; i += 1) {
        const item = document.createElement("div");
        item.className = `register-tile${changed.has(i) ? " changed" : ""}`;
        item.innerHTML = `<span>R${i}</span><strong>${cpu.registers[i]}</strong>`;
        els.registerGrid.appendChild(item);
    }
}

function renderMemory() {
    const cpu = state.cpu;
    const changed = new Set(cpu.lastChanges.memory);
    els.memoryGrid.innerHTML = "";
    for (let i = 0; i < MEMORY_SIZE; i += 1) {
        const cell = document.createElement("div");
        const isPc = i === cpu.pc || (i > cpu.pc && i < cpu.pc + 4);
        const isResult = i === 250;
        cell.className = [
            "memory-cell",
            changed.has(i) ? "changed" : "",
            isPc ? "pc" : "",
            isResult ? "result" : "",
            cpu.memory[i] === 0 ? "zero" : ""
        ].filter(Boolean).join(" ");
        cell.title = `MEM[${i}] = ${cpu.memory[i]}`;
        cell.innerHTML = `<span>${i}</span><strong>${cpu.memory[i]}</strong>`;
        els.memoryGrid.appendChild(cell);
    }
}

function renderListing() {
    const cpu = state.cpu;
    els.listingBody.innerHTML = "";
    for (const item of state.assembled.listing) {
        const row = document.createElement("tr");
        const isCurrent = item.address === cpu.pc;
        const hasBreakpoint = state.breakpoints.has(item.address);
        row.className = `${isCurrent ? "current" : ""} ${hasBreakpoint ? "breakpoint" : ""}`;
        row.innerHTML = `
            <td><button class="breakpoint-btn" data-address="${item.address}" title="Toggle breakpoint">${hasBreakpoint ? "●" : "○"}</button></td>
            <td>${item.address}</td>
            <td>${item.lineNumber}</td>
            <td>${formatInstruction(item)}</td>
            <td class="words">${item.words.join(" ")}</td>
        `;
        els.listingBody.appendChild(row);
    }

    els.listingBody.querySelectorAll(".breakpoint-btn").forEach((button) => {
        button.addEventListener("click", () => {
            const address = Number.parseInt(button.dataset.address, 10);
            if (state.breakpoints.has(address)) {
                state.breakpoints.delete(address);
            } else {
                state.breakpoints.add(address);
            }
            renderListing();
        });
    });
}

function renderTrace() {
    els.traceLog.innerHTML = "";
    if (state.trace.length === 0) {
        const empty = document.createElement("div");
        empty.className = "trace-empty";
        empty.textContent = "No instructions executed yet. Click Step or Run to populate the trace.";
        els.traceLog.appendChild(empty);
        return;
    }

    for (const event of state.trace.slice(0, 80)) {
        const line = document.createElement("div");
        const changeText = describeChanges(event.changes);
        line.className = "trace-line";
        line.textContent = `#${event.steps} PC ${event.pc}: ${event.opcodeName} [${event.a}, ${event.b}, ${event.c}] -> PC ${event.nextPc}${changeText}`;
        els.traceLog.appendChild(line);
    }
}

function describeChanges(changes) {
    const parts = [];
    if (changes.registers.length > 0) {
        parts.push(`R: ${changes.registers.map((i) => `R${i}`).join(",")}`);
    }
    if (changes.memory.length > 0) {
        parts.push(`MEM: ${changes.memory.join(",")}`);
    }
    return parts.length ? ` | ${parts.join(" | ")}` : "";
}

window.addEventListener("load", init);
