# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Instructions
My end goal is to build a community simulation in ascii or some other light graphics interface. To start with, we need some agents on a map. Lets do this in zig. Build out a framework that has the following functionality: agents that can be spawned, these agents have different qualities that we can add to later. The map should be written to a file. If we could store it in memory and write it to a file on a command that would be great. Lets start with this.

## Build Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig build test`
- Format code: `zig fmt src/`
- Performance test: `zig build-exe perf_test.zig -O ReleaseFast && ./perf_test [agents] [iterations]`

## Interactive Controls
- **SPACE**: Pause/resume simulation
- **RIGHT ARROW**: Advance one step when paused
- **A**: Enter agent spawn mode (then click to place)
- **1-6**: Select agent type (1=Settler, 2=Explorer, 3=Builder, 4=Farmer, 5=Miner, 6=Scout)
- **B**: Benchmark - Add 10 random agents
- **S**: Stress test - Add 100 random agents
- **ESC**: Quit

## SDL3 Integration
- The project contains a fully functional SDL3 visualization system
- To enable SDL3 support:
  1. Install SDL3 via Homebrew: `brew install sdl3`
  2. Use the helper script: `./run_gui.sh` to automatically detect and use SDL3
  3. Or run directly: `zig build -Dsdl=true && zig build run -- --gui`

The SDL3 integration provides:
- Color-coded terrain visualization
- Unique colors for different agent types
- Visual representation of agent interactions with connecting lines
- Interactive controls via keyboard and mouse
- Real-time addition of agents by clicking on the map
- Agent type selection with number keys (1-6)
- Performance metrics display
- Stress testing capabilities with thousands of agents

## Agent Types and Behaviors
The simulation includes six agent types, each with unique behaviors:
- **Settler**: Balanced movement efficiency, prefers Greeting interactions
- **Explorer**: High movement efficiency, prefers Trading with others
- **Builder**: Lower movement efficiency, prefers Collaboration
- **Farmer**: Focuses on Resource interactions, average movement
- **Miner**: Provides resources but also collaborates, slower movement 
- **Scout**: Fast movement, prefers Teaching interactions

## Interaction System
Agents can interact with each other in five different ways:
- **Greeting**: Basic social interaction
- **Trading**: Exchange of goods/services
- **Collaboration**: Working together on projects
- **Teaching**: Sharing knowledge and information
- **Resource**: Sharing or gathering resources

Interaction preference depends on agent types, and interactions last for several simulation steps.

## Multi-threading Support
- The simulation supports multi-threaded agent updates for better performance
- Thread count can be configured in simulation.zig (thread_count constant, default 4)
- Threading automatically scales based on agent count
- For small agent counts (< 2 * thread_count), it falls back to single-threading
- Proper thread-safety is maintained through mutex-protected shared state access
- With multi-threading enabled, the simulation can efficiently handle thousands of agents

## Benchmarking Features
- Performance metrics display updates/second and agent count
- Stress testing can add hundreds of agents at once
- Benchmark mode (B key) adds 10 random agents
- Stress test mode (S key) adds 100 random agents
- The simulation can run indefinitely (no step limit)
- Optimized console output to reduce clutter during long runs

## Key Components
- **main.zig**: Entry point that initializes, runs, and manages the simulation
- **renderer.zig**: SDL3 visualization code and user interface
- **simulation.zig**: Core simulation logic and agent updates
- **interactions.zig**: Interaction system between agents
- **map.zig**: Terrain management and display
- **terrain.zig**: Procedural terrain generation
- **agent.zig**: Agent types, behaviors, and movement patterns

## Project Structure and Design
- Modular codebase with clear separation of concerns
- Comprehensive test files for all major components
- Each agent has its own random seed for unique movement patterns
- Clean, organized directory structure with logical module separation
- Thread-safe access to shared resources
- Clean visualization toggle between SDL and ASCII output
- Configurable simulation parameters and display options
- Data-driven approach to agent movement and terrain effects
- Movement patterns encapsulated in reusable structures
- Component-based design with minimal coupling between systems
- Dedicated performance testing with perf_test.zig tool
- High-performance code with 169+ million agent updates per second
- Optimized movement calculations with O(1) time complexity

```zig
// Example of improved Movement struct from agent.zig
pub const Movement = struct {
    dx: i8,
    dy: i8,
    
    pub fn none() Movement {
        return .{ .dx = 0, .dy = 0 };
    }
    
    pub fn cardinal(direction: u8) Movement {
        return switch (direction) {
            0 => .{ .dx = 1, .dy = 0 },  // East
            1 => .{ .dx = 0, .dy = 1 },  // South
            2 => .{ .dx = -1, .dy = 0 }, // West
            3 => .{ .dx = 0, .dy = -1 }, // North
            else => .{ .dx = 0, .dy = 0 }
        };
    }
    
    pub fn diagonal(direction: u8) Movement {
        return switch (direction) {
            0 => .{ .dx = 1, .dy = 1 },   // Southeast
            1 => .{ .dx = -1, .dy = 1 },  // Southwest
            2 => .{ .dx = -1, .dy = -1 }, // Northwest
            3 => .{ .dx = 1, .dy = -1 },  // Northeast
            else => .{ .dx = 0, .dy = 0 }
        };
    }
    
    pub fn scale(self: Movement, factor: i8) Movement {
        return .{
            .dx = self.dx * factor,
            .dy = self.dy * factor,
        };
    }
    
    pub fn isMoving(self: Movement) bool {
        return self.dx != 0 or self.dy != 0;
    }
};
```
