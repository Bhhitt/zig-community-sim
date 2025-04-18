# Zig Community Agent Simulation

A modular, high-performance agent-based simulation written in Zig. Agents with unique behaviors and movement patterns interact in a procedurally generated 2D world, influenced by terrain and agent type.

## Features
- **Multiple agent types:** Settler, Explorer, Builder, Farmer, Miner, Scout
- **Procedural terrain:** Forests, mountains, water, grass, and more
- **Agent interactions:** Greeting, Trading, Collaboration, Teaching, Resource
- **Terrain effects:** Terrain influences agent movement, energy, and health
- **High-performance movement:** Multi-threaded agent updates for large-scale simulations
- **Graphical interface:** Real-time SDL3 visualization with interactive controls
- **Text interface:** Fast, headless mode for benchmarks and automated testing
- **Benchmarking:** Built-in stress tests and performance metrics
- **Extensible architecture:** Easy to add new agent types, terrain, or behaviors

## Getting Started

### Requirements
- Zig 0.12.0+ (tested with 0.14.0)
- (Optional) SDL3 for GUI: `brew install sdl3`

### Building and Running

#### Text Mode
```sh
zig build run -- --text
```

#### Graphical/SDL3
```sh
zig build -Dsdl=true
zig build run -- --gui
```
Or use the helper script:
```sh
./run_gui.sh
```

### Command-line Options
- `--steps=N`: Set maximum simulation steps
- `--width=W --height=H`: Set map dimensions
- `--text` or `--gui`: Choose interface mode

### Benchmarking
```sh
zig build benchmark
zig build run -- benchmark 2000 200
```

### Helper Script
```sh
./run_sim.sh --steps=500 --width=80 --height=40
```

## Controls (SDL3 GUI)
- **Space:** Pause/resume
- **Right Arrow:** Step when paused
- **A:** Enter agent spawn mode (then click to place)
- **1-6:** Select agent type
- **B:** Add 10 random agents
- **S:** Add 100 random agents
- **ESC:** Quit

## Project Structure
- `src/agents/` — Agent logic, types, movement, interactions
- `src/core/` — Simulation, configuration, core logic
- `src/world/` — Map and terrain
- `src/ui/` — Rendering, SDL3, input handling
- `benchmark.zig` — Benchmark runner
- `build.zig` — Zig build definition and module registration

## Contributing
Contributions are welcome! Please open issues or pull requests for bugfixes, improvements, or new features.

## License
MIT License