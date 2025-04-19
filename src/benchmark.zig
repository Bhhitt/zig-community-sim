// Benchmark module for running performance and stress tests on the simulation.
const std = @import("std");
const Simulation = @import("simulation").Simulation;
const AgentType = @import("agent_type").AgentType;

/// Configuration for benchmarking the simulation.
pub const BenchmarkConfig = struct {
    /// The number of agents to simulate.
    agent_count: usize = 1000,
    /// The number of iterations to run the simulation for.
    iterations: usize = 100,
    /// The width of the map.
    map_width: usize = 200,
    /// The height of the map.
    map_height: usize = 200,
    // Simulation config fields for compatibility
    food_spawn_chance: u8 = 10,
    food_regrow_chance: f32 = 0.02,
    hunger_threshold: u8 = 80,
    hunger_health_penalty: u8 = 1,
    thread_count: usize = 1,
};

/// Runs a benchmark with the given allocator and configuration.
/// 
/// This function creates a simulation with the specified configuration, adds agents to the map,
/// and then runs the simulation for the specified number of iterations. It prints out the results
/// of the benchmark, including the total time taken and the average iteration time.
pub fn runBenchmark(allocator: std.mem.Allocator, config: BenchmarkConfig) !void {
    // Create a large simulation
    std.debug.print("Starting benchmark with {d} agents for {d} iterations...\n", 
        .{config.agent_count, config.iterations});
    
    var simulation = try Simulation.init(allocator, config.map_width, config.map_height, config);
    defer simulation.deinit();
    
    // Add agents
    std.debug.print("Adding {d} agents to map...\n", .{config.agent_count});
    
    const start_time = std.time.milliTimestamp();
    var agent_count: usize = 0;
    
    // Add agents of each type evenly distributed
    const agent_types = [_]AgentType{
        .Settler, .Explorer, .Builder, .Farmer, .Miner, .Scout
    };
    
    while (agent_count < config.agent_count) : (agent_count += 1) {
        const agent_type = agent_types[@mod(agent_count, agent_types.len)];
        const x = @mod(agent_count * 17, config.map_width);
        const y = @mod(agent_count * 19, config.map_height);
        
        try simulation.spawnAgent(.{
            .x = x,
            .y = y,
            .type = agent_type,
            .health = 100,
            .energy = 100,
        });
    }
    
    const setup_time = std.time.milliTimestamp() - start_time;
    std.debug.print("Setup completed in {d} ms\n", .{setup_time});
    
    // Run benchmark
    std.debug.print("Running simulation for {d} iterations...\n", .{config.iterations});
    
    const benchmark_start = std.time.milliTimestamp();
    
    // Run iterations
    for (0..config.iterations) |i| {
        const iteration_start = std.time.milliTimestamp();
        try simulation.update(allocator, config);
        const iteration_time = std.time.milliTimestamp() - iteration_start;
        
        if (i % 10 == 0 or i == config.iterations - 1) {
            std.debug.print("Iteration {d}/{d} completed in {d} ms\n", 
                .{i + 1, config.iterations, iteration_time});
        }
    }
    
    const total_time = std.time.milliTimestamp() - benchmark_start;
    const avg_iteration_time = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(config.iterations));
    
    // Print results
    std.debug.print("\nBenchmark Results:\n", .{});
    std.debug.print("------------------\n", .{});
    std.debug.print("Total agents: {d}\n", .{config.agent_count});
    std.debug.print("Map size: {d} x {d}\n", .{config.map_width, config.map_height});
    std.debug.print("Iterations: {d}\n", .{config.iterations});
    std.debug.print("Total time: {d} ms\n", .{total_time});
    std.debug.print("Average iteration time: {d:.2} ms\n", .{avg_iteration_time});
    std.debug.print("Agents processed per second: {d:.2}\n", 
        .{@as(f64, @floatFromInt(config.agent_count)) * 1000.0 / avg_iteration_time});
}

fn runAndReportBenchmark(allocator: std.mem.Allocator, config: BenchmarkConfig, label: []const u8) !void {
    std.debug.print("\n=== Benchmark ({s}) ===\n", .{label});
    try runBenchmark(allocator, config);
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const base_config = BenchmarkConfig{};
    // Single-threaded
    try runAndReportBenchmark(gpa, base_config, "single-threaded");
    // Multi-threaded (use half or all available cores, or set to 4 for demo)
    var mt_config = base_config;
    mt_config.thread_count = 4;
    try runAndReportBenchmark(gpa, mt_config, "multi-threaded (4 threads)");
}