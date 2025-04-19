# Zig Community Agent Simulation — Usage Guide

## Features

- Modular, high-performance agent-based simulation in Zig
- Multiple agent types (Settler, Explorer, Builder, Farmer, Miner, Scout)
- Procedural terrain, agent interactions, terrain effects
- Multi-threaded updates, graphical (SDL3) and text modes
- Built-in benchmarking and performance micro-benchmarks

---

## Requirements

- **Zig** 0.12.0+ (tested with 0.14.0)
- **(Optional) SDL3** for GUI:  
  `brew install sdl3`

---

## Building and Running

### Text Mode (Headless)

```sh
zig build run -- --text
```

### Graphical Mode (SDL3)

```sh
zig build -Dsdl=true
zig build run -- --gui
```
Or use the helper script:
```sh
./run_gui.sh
```

### Command-line Options

- `--steps=N` — Set max simulation steps
- `--width=W --height=H` — Set map dimensions
- `--text` or `--gui` — Choose interface mode

### Helper Script Example

```sh
./run_sim.sh --steps=500 --width=80 --height=40
```

---

## Running Tests

To run all tests:

```sh
./run_tests.sh
```
or
```sh
zig build test
```

---

## Benchmarking

### Full-system Benchmark

```sh
zig build benchmark
zig build run -- benchmark 2000 200
```

### Micro-benchmark (Agent Updates)

```sh
zig run perf_test.zig
```
- Compares single-threaded and multi-threaded agent update performance.

---

## SDL3 GUI Controls

- **Space:** Pause/resume
- **Right Arrow:** Step when paused
- **A:** Enter agent spawn mode (then click to place)
- **1-6:** Select agent type
- **B:** Add 10 random agents

---

## Extending the Simulation

- Add new agent types, terrain, or behaviors by editing files in `src/agents/` and `src/world/`.
- Register new modules in `build.zig` for use in tests (see project memories for details).
- Tests for new logic should be placed in the `tests/` directory and use module imports as defined in `build.zig`.

---

## Troubleshooting

- If tests fail with import errors, ensure all relevant modules are registered in `build.zig`.
- For SDL3 errors, confirm SDL3 is installed (`brew install sdl3`).
