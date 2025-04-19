// Benchmark module for running performance and stress tests on the simulation.
const std = @import("std");
const Simulation = @import("simulation").Simulation;
const AgentType = @import("agent_type").AgentType;
const Agent = @import("agent").Agent;

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
    interaction_awareness_radius: usize = 5,
    interaction_desire_chance: u8 = 30,
};

// --- Helper for agent stats ---
fn agentStats(agents: []const Agent) struct {
    avg_health: f32,
    min_health: f32,
    max_health: f32,
    avg_energy: f32,
    min_energy: f32,
    max_energy: f32,
} {
    var sum_health: f32 = 0;
    var min_health: f32 = 10000;
    var max_health: f32 = -10000;
    var sum_energy: f32 = 0;
    var min_energy: f32 = 10000;
    var max_energy: f32 = -10000;
    for (agents) |agent| {
        const health_f: f32 = @floatFromInt(agent.health);
        sum_health += health_f;
        if (health_f < min_health) min_health = health_f;
        if (health_f > max_health) max_health = health_f;
        const energy_f: f32 = @floatFromInt(agent.energy);
        sum_energy += energy_f;
        if (energy_f < min_energy) min_energy = energy_f;
        if (energy_f > max_energy) max_energy = energy_f;
    }
    const count: f32 = @floatFromInt(agents.len);
    return .{
        .avg_health = sum_health / count,
        .min_health = min_health,
        .max_health = max_health,
        .avg_energy = sum_energy / count,
        .min_energy = min_energy,
        .max_energy = max_energy,
    };
}

// --- CSV Export ---
fn exportCsv(
    file: *std.fs.File,
    config: BenchmarkConfig,
    setup_time: i64,
    sim_time: i64,
    wall_time: i64,
    mem_used: usize,
    stats: anytype,
    label: []const u8,
) !void {
    try file.writer().print(
        "{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n",
        .{
            label,
            config.agent_count,
            config.iterations,
            config.thread_count,
            setup_time,
            sim_time,
            wall_time,
            mem_used,
            stats.avg_health,
            stats.min_health,
            stats.max_health,
            stats.avg_energy,
            stats.min_energy,
            stats.max_energy,
        },
    );
}

/// Runs a benchmark with the given allocator and configuration.
/// 
/// This function creates a simulation with the specified configuration, adds agents to the map,
/// and then runs the simulation for the specified number of iterations. It prints out the results
/// of the benchmark, including the total time taken and the average iteration time.
pub fn runBenchmark(allocator: std.mem.Allocator, _: ?*usize, config: BenchmarkConfig) !void {
    const start_wall = std.time.milliTimestamp();
    
    std.debug.print("Starting benchmark with {d} agents for {d} iterations...\n", 
        .{config.agent_count, config.iterations});
    
    var simulation = try Simulation.init(allocator, config.map_width, config.map_height, config);
    defer simulation.deinit();
    
    // Add agents
    std.debug.print("Adding {d} agents to map...\n", .{config.agent_count});
    
    const start_setup = std.time.milliTimestamp();
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
    
    const end_setup = std.time.milliTimestamp();
    const setup_time = end_setup - start_setup;
    std.debug.print("Setup completed in {d} ms\n", .{setup_time});
    
    // Run benchmark
    std.debug.print("Running simulation for {d} iterations...\n", .{config.iterations});
    
    const start_sim = std.time.milliTimestamp();
    
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
    
    const end_sim = std.time.milliTimestamp();
    const sim_time = end_sim - start_sim;
    
    // Agent stats
    const stats = agentStats(simulation.agents.items);
    
    // Report
    std.debug.print("\nBenchmark Results:\n------------------\n", .{});
    std.debug.print("Total agents: {d}\n", .{config.agent_count});
    std.debug.print("Map size: {d} x {d}\n", .{config.map_width, config.map_height});
    std.debug.print("Iterations: {d}\n", .{config.iterations});
    std.debug.print("Setup time: {d} ms\n", .{setup_time});
    std.debug.print("Simulation time: {d} ms\n", .{sim_time});
    std.debug.print("Total wall time: {d} ms\n", .{std.time.milliTimestamp() - start_wall});
    std.debug.print("Agent health (avg/min/max): {d:.2}/{d:.2}/{d:.2}\n", .{stats.avg_health, stats.min_health, stats.max_health});
    std.debug.print("Agent energy (avg/min/max): {d:.2}/{d:.2}/{d:.2}\n", .{stats.avg_energy, stats.min_energy, stats.max_energy});
    
    // CSV export
    // Create a filename using benchmark parameters
    var filename_buf: [128]u8 = undefined;
    const filename = try std.fmt.bufPrint(
        &filename_buf, 
        "tests/benchmark_results_{d}_{d}_{d}.csv", 
        .{config.agent_count, config.iterations, config.thread_count}
    );
    
    var csv_file = try std.fs.cwd().createFile(filename, .{});
    defer csv_file.close();
    
    // Write CSV header
    try csv_file.writer().print(
        "label,agent_count,iterations,thread_count,setup_time,sim_time,wall_time,mem_used,avg_health,min_health,max_health,avg_energy,min_energy,max_energy\n",
        .{}
    );
    
    try exportCsv(
        &csv_file,
        config,
        setup_time,
        sim_time,
        std.time.milliTimestamp() - start_wall,
        0,
        stats,
        "benchmark"
    );
}

fn runAndReportBenchmark(allocator: std.mem.Allocator, _: ?*usize, config: BenchmarkConfig, label: []const u8) !void {
    std.debug.print("\n=== Benchmark ({s}) [agents: {d}, iterations: {d}, threads: {d}] ===\n",
        .{label, config.agent_count, config.iterations, config.thread_count});
    const start_time = std.time.milliTimestamp();
    try runBenchmark(allocator, null, config);
    const end_time = std.time.milliTimestamp();
    std.debug.print("Total benchmark wall time: {d} ms\n", .{end_time - start_time});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    // Process command line arguments for more flexible benchmarking
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Default configuration
    var config = BenchmarkConfig{
        .agent_count = 5000,
        .iterations = 100,
        .thread_count = 4,
    };
    
    // Process command-line arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--threads") and i + 1 < args.len) {
            i += 1;
            config.thread_count = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--agents") and i + 1 < args.len) {
            i += 1;
            config.agent_count = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--iterations") and i + 1 < args.len) {
            i += 1;
            config.iterations = try std.fmt.parseInt(usize, args[i], 10);
        }
    }
    
    // If no arguments provided, run tests with multiple thread configurations
    if (args.len <= 1) {
        std.debug.print("Running with default thread count series...\n", .{});
        const thread_configs = [_]usize{1, 2, 4, 8};
        
        for (thread_configs) |thread_count| {
            var thread_config = config;
            thread_config.thread_count = thread_count;
            const label = if (thread_count == 1) "single-threaded" else "multi-threaded";
            try runAndReportBenchmark(allocator, null, thread_config, 
                std.fmt.allocPrint(allocator, "{s} ({d} threads)", .{label, thread_count}) catch "benchmark");
        }
    } else {
        // Run with the specific configuration from command line
        const label = if (config.thread_count == 1) "single-threaded" else "multi-threaded";
        try runAndReportBenchmark(allocator, null, config, 
            std.fmt.allocPrint(allocator, "{s} ({d} threads)", .{label, config.thread_count}) catch "benchmark");
    }
}