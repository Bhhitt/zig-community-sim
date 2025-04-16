# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Instructions
My end goal is to build a community simulation in ascii or some other light graphics interface. To start with, we need some agents on a map. Lets do this in zig. Build out a framework that has the following functionality: agents that can be spawned, these agents have different qualities that we can add to later. The map should be written to a file. If we could store it in memory and write it to a file on a command that would be great. Lets start with this.

## Build Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig test src/[file].zig`
- Format code: `zig fmt src/`

## SDL3 Integration (Experimental)
- The project contains a renderer.zig module that supports SDL3 visualization
- To enable SDL3 support:
  1. Ensure SDL3 is installed or available via the included libraries
  2. Update build.zig to link SDL3
  3. Set USE_SDL = true in main.zig

Note: Only a few SDL3 files are actually needed for this project:
- SDL3/vendored/SDL/build/libSDL3.dylib (the main library file)
- SDL3/vendored/SDL/include/SDL3/*.h (header files - specifically SDL.h and related graphics headers)
- The rest of the SDL3 source files and build artifacts are not necessary for this project

## Multi-threading Support
- The simulation now supports multi-threaded agent updates for better performance
- Thread count can be configured in simulation.zig (thread_count constant)
- Threading automatically scales based on agent count
- For small agent counts (< 2 * thread_count), it falls back to single-threading
- Proper thread-safety is maintained through mutex-protected shared state access

⏺ Based on my review, everything looks good and properly organized. Here's a summary of what we're using and how everything fits together:

  1. SDL3 Integration:
    - The compiled SDL3 library is in SDL3/vendored/SDL/build/libSDL3.dylib
    - We're linking to it properly from build.zig
    - We include the headers from SDL3/vendored/SDL/include/SDL3
    - We've set a proper rpath to find the library at runtime
    - Only these library and header files are necessary; the rest of the SDL3 source code and build files can be ignored
  2. Key Components:
    - main.zig: The entry point that initializes, runs, and manages the simulation
    - renderer.zig: Contains the SDL3 visualization code
    - simulation.zig: Handles the simulation logic including agent movement and interactions
    - map.zig: Manages the terrain and rendering the ASCII map
    - agent.zig: Defines the agent types, behaviors, and interactions
  3. Agent Randomness:
    - Each agent has its own random seed for unique movement patterns
    - Seeds are updated with each simulation step for continued randomness
    - Interaction types are determined using combined agent seeds
  4. Multi-threading:
    - Agent updates are processed in parallel for improved performance
    - The system automatically adjusts between single and multi-threaded modes
    - Thread-safe data access is ensured through proper mutex usage
  5. Clean Integration Toggle:
    - There's a USE_SDL constant in main.zig that can be set to true or false
    - When true, it initializes the SDL renderer and shows a graphical view
    - When false, it falls back to ASCII-only output in the terminal
    - The simulation still runs properly in either mode
  6. Comprehensive Testing:
    - All components have dedicated test files
    - Tests cover both single-threaded and multi-threaded functionality
    - Agent randomness is properly verified

  The structure of the codebase is very clean and modular, using Zig's features effectively with good separation of concerns.
  The SDL3 integration is properly encapsulated in the renderer module, making it easy to extend or modify in the future.
