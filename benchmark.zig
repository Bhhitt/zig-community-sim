const std = @import("std");
const random = std.crypto.random;
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Map = @import("map").Map;
const Terrain = @import("terrain").Terrain;
const Simulation = @import("simulation").Simulation;
const AppConfig = @import("config").AppConfig;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    var agent_count: usize = 500;
    var iterations: usize = 1000;
    var thread_count: usize = 1;
    const map_width: usize = 40;
    const map_height: usize = 20;
    
    // Parse arguments using flags for better usability
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--agents") and i + 1 < args.len) {
            agent_count = try std.fmt.parseInt(usize, args[i + 1], 10);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--iterations") and i + 1 < args.len) {
            iterations = try std.fmt.parseInt(usize, args[i + 1], 10);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--threads") and i + 1 < args.len) {
            thread_count = try std.fmt.parseInt(usize, args[i + 1], 10);
            i += 1;
        }
    }
    
    std.debug.print("\n=== Running Agent Movement Benchmark ===\n", .{});
    std.debug.print("Map size: {d}x{d}, Agents: {d}, Iterations: {d}, Threads: {d}\n",
        .{map_width, map_height, agent_count, iterations, thread_count});
    
    // Create simulation config
    var config = AppConfig{
        .map_width = map_width,
        .map_height = map_height,
        .thread_count = thread_count,
        .running_delay_ms = 0, // No delay for benchmarks
    };
    
    // Create simulation
    var sim = try Simulation.init(allocator, map_width, map_height, config);
    defer sim.deinit();
    
    // Create agents
    try createAgentsInSimulation(&sim, agent_count);
    
    // Run the simulation and measure performance
    const start_time = std.time.milliTimestamp();
    
    // Run the simulation for specified iterations
    for (0..iterations) |iter| {
        try sim.update(allocator, config);
        
        if (iter % 100 == 0 and iter > 0) {
            std.debug.print("Completed {d} iterations...\r", .{iter});
        }
    }
    
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;
    
    // Print performance metrics
    std.debug.print("\nPerformance Results with {d} threads:\n", .{thread_count});
    std.debug.print("- Total time: {d}ms\n", .{duration_ms});
    std.debug.print("- Average time per iteration: {d:.3}ms\n", 
        .{@as(f64, @floatFromInt(duration_ms)) / @as(f64, @floatFromInt(iterations))});
    std.debug.print("- Average time per agent per iteration: {d:.6}ms\n", 
        .{@as(f64, @floatFromInt(duration_ms)) / 
          (@as(f64, @floatFromInt(iterations)) * @as(f64, @floatFromInt(sim.agents.items.len)))});
    std.debug.print("- Updates per second: {d:.1}\n", 
        .{@as(f64, @floatFromInt(sim.agents.items.len)) * @as(f64, @floatFromInt(iterations)) * 1000.0 / 
          @as(f64, @floatFromInt(duration_ms))});
    
    // Check agent health and energy distribution
    var health_sum: usize = 0;
    var energy_sum: usize = 0;
    
    for (sim.agents.items) |agent| {
        health_sum += agent.health;
        energy_sum += agent.energy;
    }
    
    const avg_health = @as(f64, @floatFromInt(health_sum)) / @as(f64, @floatFromInt(sim.agents.items.len));
    const avg_energy = @as(f64, @floatFromInt(energy_sum)) / @as(f64, @floatFromInt(sim.agents.items.len));
    
    std.debug.print("\nAgent Status After Simulation:\n", .{});
    std.debug.print("- Average health: {d:.2}\n", .{avg_health});
    std.debug.print("- Average energy: {d:.2}\n", .{avg_energy});
    std.debug.print("- Interactions: {d}\n", .{sim.interaction_system.getInteractions().len});
    std.debug.print("=== Benchmark Complete ===\n\n", .{});
    
    // Save results to a file
    try saveResultsToFile(
        allocator, 
        sim, 
        duration_ms, 
        iterations, 
        thread_count, 
        agent_count
    );
}

// Create agents in the simulation
fn createAgentsInSimulation(
    sim: *Simulation,
    count: usize
) !void {
    const agent_types = [_]AgentType{
        .Settler, .Explorer, .Builder, .Farmer, .Miner, .Scout
    };
    
    for (0..count) |i| {
        const x = random.uintLessThan(usize, sim.map.width);
        const y = random.uintLessThan(usize, sim.map.height);
        const agent_type = agent_types[random.uintLessThan(usize, agent_types.len)];
        
        try sim.spawnAgent(.{
            .x = x,
            .y = y,
            .type = agent_type,
            .health = 100,
            .energy = 100,
        });
    }
}

// Save benchmark results to a CSV file
fn saveResultsToFile(
    allocator: std.mem.Allocator,
    sim: Simulation,
    duration_ms: i64,
    iterations: usize,
    thread_count: usize,
    agent_count: usize,
) !void {
    const filename = try std.fmt.allocPrint(
        allocator, 
        "benchmark_results_{d}_{d}_{d}.csv", 
        .{agent_count, iterations, thread_count}
    );
    defer allocator.free(filename);
    
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    
    const writer = file.writer();
    
    // Write CSV header
    try writer.writeAll("thread_count,agent_count,iterations,duration_ms,ms_per_iteration,ms_per_agent_iteration,updates_per_second,avg_health,avg_energy\n");
    
    // Calculate metrics
    const ms_per_iteration = @as(f64, @floatFromInt(duration_ms)) / @as(f64, @floatFromInt(iterations));
    const ms_per_agent_iteration = @as(f64, @floatFromInt(duration_ms)) / (@as(f64, @floatFromInt(iterations)) * @as(f64, @floatFromInt(sim.agents.items.len)));
    const updates_per_second = @as(f64, @floatFromInt(sim.agents.items.len)) * @as(f64, @floatFromInt(iterations)) * 1000.0 / @as(f64, @floatFromInt(duration_ms));
    
    // Calculate agent stats
    var health_sum: usize = 0;
    var energy_sum: usize = 0;
    
    for (sim.agents.items) |agent| {
        health_sum += agent.health;
        energy_sum += agent.energy;
    }
    
    const avg_health = @as(f64, @floatFromInt(health_sum)) / @as(f64, @floatFromInt(sim.agents.items.len));
    const avg_energy = @as(f64, @floatFromInt(energy_sum)) / @as(f64, @floatFromInt(sim.agents.items.len));
    
    // Write results row
    try writer.print("{d},{d},{d},{d},{d:.3},{d:.6},{d:.1},{d:.2},{d:.2}\n",
        .{
            thread_count,
            agent_count,
            iterations,
            duration_ms,
            ms_per_iteration,
            ms_per_agent_iteration,
            updates_per_second,
            avg_health,
            avg_energy,
        }
    );
}

// The terrain generation is now handled by TerrainGenerator in the simulation initialization