# Community Simulation

A multi-agent community simulation written in Zig with SDL3 visualization.

## About This Project

**Disclaimer: This code was entirely authored by Claude AI from Anthropic through Claude Code.**

I used Claude Code to build this project from scratch—I didn't write a single line of code myself. This project demonstrates Claude's ability to design, implement, and optimize a fairly complex simulation system entirely through conversation.

## Project Overview

This is a community simulation featuring different types of agents interacting on a procedurally generated map. The simulation includes:

- Six agent types (Settler, Explorer, Builder, Farmer, Miner, Scout) with unique behaviors
- Social interactions between nearby agents (Greeting, Trading, Collaboration, Teaching, Resource)
- ASCII and graphical visualization using SDL3
- Multi-threading for efficient processing of large agent populations
- Benchmarking and stress testing capabilities

## Requirements

- Zig 0.14.0 or later
- SDL3 library (required for graphical visualization)
  - The SDL3 library file should be in `SDL3/vendored/SDL/build/libSDL3.dylib`
  - The SDL3 header files should be in `SDL3/vendored/SDL/include/SDL3/`

## Running the Simulation

```bash
# Build the project
zig build

# Run the simulation
zig build run
```

## Controls

- **SPACE**: Pause/resume simulation
- **RIGHT ARROW**: Advance one step when paused
- **A**: Enter agent spawn mode (then click to place)
- **1-6**: Select agent type (1=Settler, 2=Explorer, 3=Builder, 4=Farmer, 5=Miner, 6=Scout)
- **B**: Benchmark - Add 10 random agents
- **S**: Stress test - Add 100 random agents
- **ESC**: Quit

## Notes on Implementation

The project features:
- Multi-threaded agent processing for high performance
- Thousands of agents can be simulated simultaneously
- Clean separation of logic between simulation and visualization
- Optimized console output for long-running simulations

## Claude's Capabilities

To build this project, Claude demonstrated its ability to:
1. Design a modular system architecture
2. Implement complex algorithms (pathfinding, terrain generation, multi-threading)
3. Handle SDL3 integration for visualization
4. Debug and optimize performance issues
5. Extend and enhance existing functionality
6. Write comprehensive documentation and tests

This project was an experiment to see how far an AI assistant could go in autonomously building a non-trivial software project.