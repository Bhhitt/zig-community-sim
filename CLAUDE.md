# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Instructions
My end goal is to build a community simulation in ascii or some other light graphics interface. To start with, we need some agents on a map. Lets do this in zig. Build out a framework that has the following functionality: agents that can be spawned, these agents have different qualities that we can add to later. The map should be written to a file. If we could store it in memory and write it to a file on a command that would be great. Lets start with this.

## Build Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig test src/[file].zig`
- Format code: `zig fmt src/`

## Interactive Controls
- **SPACE**: Pause/resume simulation
- **RIGHT ARROW**: Advance one step when paused
- **A**: Enter agent spawn mode (then click to place)
- **1-6**: Select agent type (1=Settler, 2=Explorer, 3=Builder, 4=Farmer, 5=Miner, 6=Scout)
- **B**: Benchmark - Add 10 random agents
- **S**: Stress test - Add 100 random agents
- **ESC**: Quit

## SDL3 Integration
- The project contains a renderer.zig module that supports SDL3 visualization
- To enable SDL3 support:
  1. Ensure SDL3 is installed or available via the included libraries
  2. Update build.zig to link SDL3
  3. Set USE_SDL = true in main.zig (currently true by default)

Note: Only a few SDL3 files are actually needed for this project:
- SDL3/vendored/SDL/build/libSDL3.dylib (the main library file)
- SDL3/vendored/SDL/include/SDL3/*.h (header files - specifically SDL.h and related graphics headers)
- The rest of the SDL3 source files and build artifacts are not necessary for this project

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
- **simulation.zig**: Core simulation logic, agent updates, and interactions
- **map.zig**: Terrain generation and management
- **agent.zig**: Agent types, behaviors, and interaction definitions

## Project Structure and Design
- Modular codebase with clear separation of concerns
- SDL3 integration properly encapsulated in the renderer module
- Comprehensive test files for all major components
- Each agent has its own random seed for unique movement patterns
- Thread-safe access to shared resources
- Clean visualization toggle between SDL and ASCII output
- Configurable simulation parameters and display options

```zig
// Example of core simulation update function
pub fn update(self: *Simulation) !void {
    const agent_count = self.agents.items.len;
    
    // Skip threading if very few agents
    if (agent_count < thread_count * 2) {
        // Use original single-threaded approach for small agent counts
        for (self.agents.items) |*agent| {
            if (!self.isInteracting(agent.id)) {
                agent.update(&self.map);
                
                // Map bounds are now checked within the agent update, but just to be safe
                if (agent.x >= self.map.width) {
                    agent.x = self.map.width - 1;
                }
                if (agent.y >= self.map.height) {
                    agent.y = self.map.height - 1;
                }
            }
        }
    } else {
        // Use multi-threaded approach for larger agent counts
        var mutex = Thread.Mutex{};
        var threads: [thread_count]Thread = undefined;
        var contexts: [thread_count]AgentUpdateContext = undefined;
        
        const batch_size = (agent_count + thread_count - 1) / thread_count; // Ceiling division
        
        // Create and start threads
        for (0..thread_count) |i| {
            const start = i * batch_size;
            const end = @min(start + batch_size, agent_count);
            
            // Skip empty batches
            if (start >= agent_count) continue;
            
            contexts[i] = AgentUpdateContext{
                .agents = self.agents.items,
                .simulation = self,
                .start_index = start,
                .end_index = end,
                .mutex = &mutex,
            };
            
            threads[i] = try Thread.spawn(.{}, updateAgentBatch, .{&contexts[i]});
        }
        
        // Wait for all threads to complete
        for (0..thread_count) |i| {
            if (i * batch_size < agent_count) {
                threads[i].join();
            }
        }
    }
    
    // Update interactions (this remains single-threaded for simplicity)
    try self.updateInteractions();
}
```
