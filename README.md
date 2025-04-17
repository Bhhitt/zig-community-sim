# Agent Simulation in Zig

This project implements a simulation of agents with different behaviors and movement patterns in a 2D world. The system features multiple agent types, terrain interactions, and high-performance movement algorithms.

## Running the Simulation

The simulation features procedurally generated terrain and agents that move around and interact with each other based on their type and the terrain they're on.

Each run creates a unique world with:
- Procedurally generated terrain (forests, mountains, water, grass)
- Agents that move according to their type-specific patterns
- Interactions between agents when they meet
- Influence of terrain on agent movement and stats

### Text-based Interface (Default and Recommended)
```bash
zig build run
# or explicitly specify text mode
zig build run -- --text
```

### Set Maximum Steps
You can specify a maximum number of steps to run:
```bash
zig build run -- --steps=200
```

### Customize Map Size
You can set the dimensions of the map:
```bash
zig build run -- --width=80 --height=40
```

### Run with Multiple Options
```bash
zig build run -- --text --steps=200 --width=80 --height=40
```

### Run Benchmark
```bash
zig build benchmark
```
or with custom parameters:
```bash
zig build run -- benchmark 2000 200
```
(2000 agents for 200 iterations)

### Using the Helper Script
A helper script is included to simplify running the simulation:
```bash
./run_sim.sh --steps=500 --width=80 --height=40
```

Run `./run_sim.sh --help` for all available options.

### Note on SDL3 Support
While the project has code for SDL3 integration, there are currently issues with the SDL3 initialization. The text-based interface is the recommended way to run the simulation. If you want to experiment with the SDL3 integration, you would need to:

1. Install SDL3: `brew install sdl3`
2. Fix the SDL3 integration in the code
3. Run: `zig build -Dsdl=true run -- --gui`

## Simulation Controls

In the text-based mode, the following automated controls are available:
- Auto-pause toggle every 100 frames
- Add 10 benchmark agents every 300 frames
- Add 100 stress test agents every 1000 frames
- Auto-quit after 3000 frames

## Project Structure

```
/
├── src/                  # Source code
│   ├── agents/           # Agent-related code
│   │   ├── agent.zig     # Agent implementation
│   │   ├── agent_type.zig # Agent type definitions
│   │   ├── interaction_type.zig # Interaction system
│   │   ├── movement.zig  # Movement patterns and calculations
│   │   └── terrain_effects.zig # Terrain interaction effects
│   ├── core/             # Core simulation components
│   │   ├── app.zig       # Application controller
│   │   ├── config.zig    # Configuration settings
│   │   ├── interactions.zig # Interaction system
│   │   └── simulation.zig # Simulation engine
│   ├── ui/               # User interface components
│   │   ├── drawing.zig   # Drawing utilities
│   │   ├── input_handler.zig # Input management
│   │   ├── render_config.zig # Rendering configuration
│   │   └── renderer.zig  # Rendering system
│   ├── world/            # World-related code
│   │   ├── map.zig       # Map implementation
│   │   └── terrain.zig   # Terrain types and generation
│   ├── main.zig          # Entry point
│   └── build_options.zig # Build configuration options
├── build.zig             # Build system configuration
├── perf_test.zig         # Performance testing tool
└── tests/                # Test files
    ├── main.zig          # Main test runner
    ├── agent_tests.zig   # Tests for basic agent functionality
    ├── interaction_tests.zig # Tests for agent interactions
    ├── movement_tests.zig    # Tests for agent movement 
    ├── integration_tests.zig # Integration tests for the system
    └── utils/            # Test utilities
        └── test_utils.zig # Helper functions for tests
```

## Agent Types

The simulation supports different types of agents, each with its own behavior:

- **Settler**: Low mobility, prefers staying in one place
- **Explorer**: High mobility, explores the world quickly
- **Builder**: Move in patterns, focusing on construction
- **Farmer**: Stays near home location, prefers grass terrain
- **Miner**: Seeks mountain terrain for resources
- **Scout**: Fast-moving, can move diagonally, uses spiral patterns

## Terrain Types

The world consists of procedurally generated terrain that affects agent movement and stats:

- **Empty** (Space): Default neutral terrain
- **Grass** (`,`): Beneficial for Settlers and Farmers, provides energy and health benefits 
- **Forest** (`F`): Moderate movement costs for most agents, good for Scouts
- **Mountain** (`M`): Beneficial for Miners who gain energy here, difficult for most others
- **Water** (`W`): Difficult terrain with high movement costs and health penalties

The terrain is generated using a procedural algorithm that creates realistic clusters of terrain types, with each simulation run creating a unique world layout.

## Running Tests

To run all tests, use the following command:

```bash
zig build test
```

This command uses the build system to properly set up the module dependencies between files.

The build system also provides specific test targets for running individual test suites:

```bash
# Run agent-specific tests
zig build test-agents

# Run interaction tests
zig build test-interactions  

# Run movement tests
zig build test-movement

# Run integration tests
zig build test-integration
```

This approach ensures all module dependencies are correctly resolved for each test file.

## Performance Testing

The project includes a dedicated performance testing tool that measures agent update performance:

```bash
# Build and run the performance test with default settings (500 agents, 1000 iterations)
zig build-exe perf_test.zig -O ReleaseFast && ./perf_test

# Run with custom agent count and iterations
./perf_test 2000 5000  # 2000 agents, 5000 iterations
```

The performance test provides:
- Throughput metrics (updates per millisecond/second)
- Movement distribution statistics
- Agent behavior verification
- O(1) time complexity for all agent operations

Performance benchmarks show the system can process over 169 million agent updates per second on modern hardware, making it suitable for large-scale simulations.