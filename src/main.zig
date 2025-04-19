const std = @import("std");
const App = @import("app").App;
const AppConfig = @import("config").AppConfig;
const AgentType = @import("agent_type").AgentType;
const benchmark = @import("benchmark");
const build_options = @import("build_options");

// Variable to store max steps, available to other modules that import root
pub var max_steps: ?usize = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check for command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Check if benchmark mode is requested
    if (args.len > 1 and std.mem.eql(u8, args[1], "benchmark")) {
        // Extract optional benchmark parameters
        var bench_config = benchmark.BenchmarkConfig{};
        
        if (args.len > 2) {
            bench_config.agent_count = try std.fmt.parseInt(usize, args[2], 10);
        }
        if (args.len > 3) {
            bench_config.iterations = try std.fmt.parseInt(usize, args[3], 10);
        }
        
        // Run benchmark
        try benchmark.runBenchmark(allocator, null, bench_config);
        return;
    }

    // Check for CLI args to configure the simulation
    var use_sdl: bool = build_options.USE_SDL; // Use build options default
    var map_width: usize = build_options.DEFAULT_MAP_WIDTH;
    var map_height: usize = build_options.DEFAULT_MAP_HEIGHT;
    
    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--steps=")) {
            const steps_str = arg[8..];
            max_steps = try std.fmt.parseInt(usize, steps_str, 10);
        } else if (std.mem.eql(u8, arg, "--text")) {
            use_sdl = false;  // Force text mode
        } else if (std.mem.eql(u8, arg, "--gui")) {
            use_sdl = true;   // Try to use GUI mode
        } else if (std.mem.startsWith(u8, arg, "--width=")) {
            const width_str = arg[8..];
            map_width = try std.fmt.parseInt(usize, width_str, 10);
        } else if (std.mem.startsWith(u8, arg, "--height=")) {
            const height_str = arg[9..];
            map_height = try std.fmt.parseInt(usize, height_str, 10);
        }
    }
    
    // Create application with the configured options
    const config = AppConfig{
        .use_sdl = use_sdl,
        .map_width = map_width,
        .map_height = map_height,
    };
    
    var app = try App.init(allocator, config);
    defer app.deinit();
    
    // Add initial agents to the simulation
    // Place agents near each other to encourage interactions
    try app.simulation.spawnAgent(.{ .x = 5, .y = 5, .type = .Settler, .health = 100, .energy = 100 });
    try app.simulation.spawnAgent(.{ .x = 6, .y = 5, .type = .Explorer, .health = 80, .energy = 120 });
    try app.simulation.spawnAgent(.{ .x = 7, .y = 5, .type = .Builder, .health = 120, .energy = 80 });
    
    // Add the new agent types
    try app.simulation.spawnAgent(.{ .x = 8, .y = 5, .type = .Farmer, .health = 100, .energy = 100 });
    try app.simulation.spawnAgent(.{ .x = 9, .y = 5, .type = .Miner, .health = 110, .energy = 90 });
    try app.simulation.spawnAgent(.{ .x = 10, .y = 5, .type = .Scout, .health = 90, .energy = 110 });
    
    // Add more agents elsewhere
    try app.simulation.spawnAgent(.{ .x = 15, .y = 10, .type = .Settler, .health = 90, .energy = 110 });
    try app.simulation.spawnAgent(.{ .x = 15, .y = 11, .type = .Farmer, .health = 95, .energy = 95 });
    
    // Add agents to different terrains
    try app.simulation.spawnAgent(.{ .x = 25, .y = 5, .type = .Explorer, .health = 85, .energy = 115 });
    try app.simulation.spawnAgent(.{ .x = 30, .y = 15, .type = .Builder, .health = 110, .energy = 90 });
    try app.simulation.spawnAgent(.{ .x = 10, .y = 15, .type = .Scout, .health = 100, .energy = 100 });
    try app.simulation.spawnAgent(.{ .x = 20, .y = 12, .type = .Miner, .health = 105, .energy = 95 });
    
    // Add more agents that are farther apart to test the new interaction seeking
    try app.simulation.spawnAgent(.{ .x = 5, .y = 25, .type = .Settler, .health = 100, .energy = 100 });
    try app.simulation.spawnAgent(.{ .x = 10, .y = 25, .type = .Farmer, .health = 100, .energy = 100 });
    try app.simulation.spawnAgent(.{ .x = 20, .y = 30, .type = .Scout, .health = 90, .energy = 110 });
    try app.simulation.spawnAgent(.{ .x = 30, .y = 25, .type = .Miner, .health = 105, .energy = 95 });
    try app.simulation.spawnAgent(.{ .x = 35, .y = 40, .type = .Builder, .health = 110, .energy = 90 });
    try app.simulation.spawnAgent(.{ .x = 40, .y = 35, .type = .Explorer, .health = 85, .energy = 115 });
    
    // Add even more agents to increase interaction opportunities
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const x = @mod(i * 13, config.map_width - 5) + 2;
        const y = @mod(i * 7, config.map_height - 5) + 2;
        const agent_type = switch (@mod(i, 6)) {
            0 => AgentType.Settler,
            1 => AgentType.Explorer,
            2 => AgentType.Builder,
            3 => AgentType.Farmer,
            4 => AgentType.Miner,
            5 => AgentType.Scout,
            else => AgentType.Settler,
        };
        try app.simulation.spawnAgent(.{
            .x = x,
            .y = y,
            .type = agent_type,
            .health = 100,
            .energy = 100,
        });
    }
    
    // Run the application
    try app.run();
}