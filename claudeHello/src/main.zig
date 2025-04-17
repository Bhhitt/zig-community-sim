const std = @import("std");
const Agent = @import("agent.zig").Agent;
const AgentType = @import("agent.zig").AgentType;
const Map = @import("map.zig").Map;
const Simulation = @import("simulation.zig").Simulation;
const SdlRenderer = @import("renderer.zig").SdlRenderer;
const AppInput = @import("renderer.zig").AppInput;

// Configuration
const USE_SDL = true; // Enable SDL3 visualization

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize simulation
    const map_width = 60;
    const map_height = 30;
    var sim = try Simulation.init(allocator, map_width, map_height);
    defer sim.deinit();

    // Place agents near each other to encourage interactions
    try sim.spawnAgent(.{ .x = 5, .y = 5, .type = .Settler, .health = 100, .energy = 100 });
    try sim.spawnAgent(.{ .x = 6, .y = 5, .type = .Explorer, .health = 80, .energy = 120 });
    try sim.spawnAgent(.{ .x = 7, .y = 5, .type = .Builder, .health = 120, .energy = 80 });
    
    // Add the new agent types
    try sim.spawnAgent(.{ .x = 8, .y = 5, .type = .Farmer, .health = 100, .energy = 100 });
    try sim.spawnAgent(.{ .x = 9, .y = 5, .type = .Miner, .health = 110, .energy = 90 });
    try sim.spawnAgent(.{ .x = 10, .y = 5, .type = .Scout, .health = 90, .energy = 110 });
    
    // Add more agents elsewhere
    try sim.spawnAgent(.{ .x = 15, .y = 10, .type = .Settler, .health = 90, .energy = 110 });
    try sim.spawnAgent(.{ .x = 15, .y = 11, .type = .Farmer, .health = 95, .energy = 95 });
    
    // Add agents to different terrains
    try sim.spawnAgent(.{ .x = 25, .y = 5, .type = .Explorer, .health = 85, .energy = 115 });
    try sim.spawnAgent(.{ .x = 30, .y = 15, .type = .Builder, .health = 110, .energy = 90 });
    try sim.spawnAgent(.{ .x = 10, .y = 15, .type = .Scout, .health = 100, .energy = 100 });
    try sim.spawnAgent(.{ .x = 20, .y = 12, .type = .Miner, .health = 105, .energy = 95 });

    // Initialize SDL renderer if enabled
    var sdl_renderer: ?SdlRenderer = null;
    if (USE_SDL) {
        sdl_renderer = try SdlRenderer.init(map_width, map_height);
    }
    // Ensure we clean up SDL resources
    defer if (sdl_renderer) |*renderer| {
        renderer.deinit();
    };

    // Print the initial state to terminal
    std.debug.print("Initial map state:\n", .{});
    try sim.printMap();
    std.debug.print("\n", .{});

    // Simulation control flags
    var paused = false;
    var step_once = false;
    var spawn_mode = false;
    var selected_agent_type: AgentType = .Settler;
    
    // Variable to track performance
    
    // Display help message
    std.debug.print("\nControls:\n", .{});
    std.debug.print("  SPACE: Pause/resume simulation\n", .{});
    std.debug.print("  RIGHT ARROW: Advance one step when paused\n", .{});
    std.debug.print("  A: Enter agent spawn mode (then click to place)\n", .{});
    std.debug.print("  1-6: Select agent type (1=Settler, 2=Explorer, 3=Builder, 4=Farmer, 5=Miner, 6=Scout)\n", .{});
    std.debug.print("  B: Benchmark - Add 10 random agents\n", .{});
    std.debug.print("  S: Stress test - Add 100 random agents\n", .{});
    std.debug.print("  ESC: Quit\n\n", .{});

    // Define helper functions using simpler random approach
    const getRandomPosition = struct {
        fn get(width: usize, height: usize, seed: u64) struct { x: usize, y: usize } {
            // Use simple hash of seed to generate position
            const hash = seed *% 16777619;
            const x = @mod(hash, width);
            const y = @mod(hash >> 32, height);
            return .{ .x = x, .y = y };
        }
    }.get;
    
    const getRandomAgentType = struct {
        fn get(seed: u64) AgentType {
            // Use simple modulus to get agent type
            const type_idx = @mod(seed, 6);
            return switch (type_idx) {
                0 => .Settler,
                1 => .Explorer,
                2 => .Builder,
                3 => .Farmer,
                4 => .Miner,
                5 => .Scout,
                else => .Settler,
            };
        }
    }.get;
    
    const addRandomAgents = struct {
        fn add(simulation: *Simulation, base_seed: u64, count: usize, width: usize, height: usize) !void {
            std.debug.print("Adding {d} random agents...\n", .{count});
            
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const seed = base_seed +% i;
                const pos = getRandomPosition(width, height, seed);
                const agent_type = getRandomAgentType(seed);
                const health = @as(u8, 75) + @as(u8, @intCast(@mod(seed, 51))); // 75-125 range
                const energy = @as(u8, 75) + @as(u8, @intCast(@mod(seed >> 32, 51))); // 75-125 range
                
                try simulation.spawnAgent(.{
                    .x = pos.x,
                    .y = pos.y,
                    .type = agent_type,
                    .health = health,
                    .energy = energy,
                });
            }
            
            std.debug.print("Added {d} random agents. Total agents: {d}\n", .{count, simulation.agents.items.len});
        }
    }.add;
    
    // Simulation loop
    var quit = false;
    var i: usize = 0;
    var last_performance_check = std.time.milliTimestamp();
    var frames_since_check: usize = 0;
    var current_fps: f32 = 0;
    
    while (!quit) {
        // Process inputs
        var app_input = AppInput{ .quit = false, .paused = paused, .step = false, .spawn_requested = false };
        
        if (USE_SDL) {
            if (sdl_renderer) |*renderer| {
                // Process SDL events and check if user wants to quit or control simulation
                app_input = renderer.processEvents(spawn_mode, paused);
                quit = app_input.quit;
                paused = app_input.paused;
                step_once = app_input.step;
                
                // Handle agent type selection
                if (app_input.agent_type_changed) {
                    selected_agent_type = app_input.selected_agent_type;
                    std.debug.print("Selected agent type: {s}\n", .{@tagName(selected_agent_type)});
                }
                
                // Toggle spawn mode
                if (app_input.toggle_spawn_mode) {
                    spawn_mode = !spawn_mode;
                    std.debug.print("Spawn mode: {}\n", .{spawn_mode});
                }
                
                // Spawn agent if requested
                if (app_input.spawn_requested and spawn_mode) {
                    // Convert screen coordinates to map coordinates
                    const map_x = @divFloor(app_input.mouse_x - renderer.windowPadding(), renderer.cellSize());
                    const map_y = @divFloor(app_input.mouse_y - renderer.windowPadding(), renderer.cellSize());
                    
                    // Make sure coordinates are within map bounds
                    if (map_x >= 0 and map_x < map_width and map_y >= 0 and map_y < map_height) {
                        try sim.spawnAgent(.{
                            .x = @intCast(map_x),
                            .y = @intCast(map_y),
                            .type = selected_agent_type,
                            .health = 100,
                            .energy = 100,
                        });
                        std.debug.print("Spawned {s} at position ({}, {})\n", .{
                            @tagName(selected_agent_type), 
                            map_x, 
                            map_y
                        });
                    }
                }
                
                // Handle benchmark request (add 10 agents)
                if (app_input.add_benchmark_agents) {
                    const timestamp = std.time.timestamp();
                    const seed: u64 = @intCast(timestamp);
                    try addRandomAgents(&sim, seed, 10, map_width, map_height);
                }
                
                // Handle stress test request (add 100 agents)
                if (app_input.add_stress_test_agents) {
                    const timestamp = std.time.timestamp();
                    const seed: u64 = @intCast(timestamp);
                    try addRandomAgents(&sim, seed, 100, map_width, map_height);
                }
            }
        }
        
        // Update simulation if not paused or if step requested
        if (!paused or step_once) {
            // Update simulation and measure performance
            
            try sim.update();
            i += 1;
            frames_since_check += 1;
            step_once = false; // Reset step flag
            
            // Calculate performance metrics every second
            const current_time = std.time.milliTimestamp();
            const elapsed = current_time - last_performance_check;
            
            if (elapsed >= 1000) { // Update every second
                current_fps = @as(f32, @floatFromInt(frames_since_check)) / (@as(f32, @floatFromInt(elapsed)) / 1000.0);
                // Print step count and performance metrics 
                std.debug.print("\rStep: {d} | ", .{i});
                sim.printStats();
                std.debug.print(" | {d:.2} updates/sec", .{current_fps});
                // Clear to end of line and return to start (don't add newline)
                std.debug.print("                      \r", .{});
                
                frames_since_check = 0;
                last_performance_check = current_time;
            }
        }
        
        // Render with SDL if enabled
        if (USE_SDL) {
            if (sdl_renderer) |renderer| {
                // Render the current state
                renderer.startFrame();
                
                // Show the map and agents
                renderer.renderSimulation(sim.map, sim.agents.items, sim.interactions.items);
                
                // Show simulation status
                renderer.renderSimulationStatus(
                    i, 
                    paused, 
                    spawn_mode, 
                    selected_agent_type, 
                    sim.agents.items.len,
                    current_fps
                );
                
                renderer.endFrame();
                
                // Add a small delay to control simulation speed
                if (!paused) {
                    std.time.sleep(100 * std.time.ns_per_ms);
                } else {
                    std.time.sleep(16 * std.time.ns_per_ms); // 60fps when paused for responsiveness
                }
            }
        } else {
            // In non-SDL mode, add a small delay and continue indefinitely
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    // Print final state and save map to file
    std.debug.print("\n\nFinal map state after {d} steps:\n", .{i});
    try sim.printMap();
    
    try sim.saveMapToFile("map_state.txt");
    std.debug.print("\nMap saved to file 'map_state.txt'\n", .{});
}