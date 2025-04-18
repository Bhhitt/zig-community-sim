const std = @import("std");
const random = std.crypto.random;
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Map = @import("map").Map;
const Terrain = @import("terrain").Terrain;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    var agent_count: usize = 500;
    var iterations: usize = 1000;
    const map_width: usize = 40;
    const map_height: usize = 20;
    
    if (args.len > 1) {
        agent_count = try std.fmt.parseInt(usize, args[1], 10);
    }
    if (args.len > 2) {
        iterations = try std.fmt.parseInt(usize, args[2], 10);
    }
    
    std.debug.print("\n=== Running Agent Movement Benchmark ===\n", .{});
    std.debug.print("Map size: {d}x{d}, Agents: {d}, Iterations: {d}\n",
        .{map_width, map_height, agent_count, iterations});
    
    // Create map
    var map = try Map.init(allocator, map_width, map_height);
    defer map.deinit();
    
    // Initialize map with terrain
    try initializeMap(&map);
    
    // Create agents
    var agents = std.ArrayList(Agent).init(allocator);
    defer agents.deinit();
    
    try createAgents(&agents, agent_count, map.width, map.height);
    
    // Run the simulation and measure performance
    const start_time = std.time.milliTimestamp();
    
    // Use multi-threaded approach if possible
    const cpu_count = std.Thread.getCpuCount() catch 1;
    const thread_count = if (cpu_count > 10) 10 else cpu_count;
    if (thread_count > 1) {
        try runParallelSimulation(&agents, &map, iterations, thread_count);
    } else {
        try runSimulation(&agents, &map, iterations);
    }
    
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;
    
    // Print performance metrics
    std.debug.print("\nPerformance Results:\n", .{});
    std.debug.print("- Total time: {d}ms\n", .{duration_ms});
    std.debug.print("- Average time per iteration: {d:.3}ms\n", 
        .{@as(f64, @floatFromInt(duration_ms)) / @as(f64, @floatFromInt(iterations))});
    std.debug.print("- Average time per agent per iteration: {d:.6}ms\n", 
        .{@as(f64, @floatFromInt(duration_ms)) / 
          (@as(f64, @floatFromInt(iterations)) * @as(f64, @floatFromInt(agents.items.len)))});
    std.debug.print("- Updates per second: {d:.1}\n", 
        .{@as(f64, @floatFromInt(agents.items.len)) * @as(f64, @floatFromInt(iterations)) * 1000.0 / 
          @as(f64, @floatFromInt(duration_ms))});
    
    // Check agent health and energy distribution
    var health_sum: usize = 0;
    var energy_sum: usize = 0;
    
    for (agents.items) |agent| {
        health_sum += agent.health;
        energy_sum += agent.energy;
    }
    
    const avg_health = @as(f64, @floatFromInt(health_sum)) / @as(f64, @floatFromInt(agents.items.len));
    const avg_energy = @as(f64, @floatFromInt(energy_sum)) / @as(f64, @floatFromInt(agents.items.len));
    
    std.debug.print("\nAgent Status After Simulation:\n", .{});
    std.debug.print("- Average health: {d:.2}\n", .{avg_health});
    std.debug.print("- Average energy: {d:.2}\n", .{avg_energy});
    std.debug.print("=== Benchmark Complete ===\n\n", .{});
}

// Single-threaded simulation
fn runSimulation(agents: *std.ArrayList(Agent), map: *Map, iterations: usize) !void {
    for (0..iterations) |iter| {
        for (agents.items) |*agent| {
            agent.update(map);
        }
        
        if (iter % 100 == 0 and iter > 0) {
            std.debug.print("Completed {d} iterations...\r", .{iter});
        }
    }
}

// Worker context for thread
const WorkerContext = struct {
    agents: []Agent,
    map: *Map,
};

// Thread worker function
fn updateAgentBatch(context: *WorkerContext) void {
    for (context.agents) |*agent| {
        agent.update(context.map);
    }
}

// Multi-threaded simulation
fn runParallelSimulation(agents: *std.ArrayList(Agent), map: *Map, iterations: usize, thread_count: usize) !void {
    var threads = try std.heap.page_allocator.alloc(std.Thread, thread_count);
    defer std.heap.page_allocator.free(threads);
    
    const agent_count = agents.items.len;
    const agents_per_thread = (agent_count + thread_count - 1) / thread_count;
    var contexts = try std.heap.page_allocator.alloc(WorkerContext, thread_count);
    defer std.heap.page_allocator.free(contexts);
    
    for (0..iterations) |iter| {
        // Configure contexts for this iteration
        for (0..thread_count) |t| {
            const start_idx = t * agents_per_thread;
            const end_idx = if (start_idx + agents_per_thread > agent_count) agent_count else start_idx + agents_per_thread;
            
            // Skip empty ranges
            if (start_idx >= agent_count) continue;
            
            contexts[t] = .{
                .agents = agents.items[start_idx..end_idx],
                .map = map,
            };
            
            // Create and start thread
            threads[t] = try std.Thread.spawn(.{}, updateAgentBatch, .{&contexts[t]});
        }
        
        // Wait for all threads
        for (0..thread_count) |t| {
            if (t * agents_per_thread < agent_count) {
                threads[t].join();
            }
        }
        
        if (iter % 100 == 0 and iter > 0) {
            std.debug.print("Completed {d} iterations...\r", .{iter});
        }
    }
}

// Create agents of different types
fn createAgents(
    agents: *std.ArrayList(Agent),
    count: usize, 
    width: usize, 
    height: usize
) !void {
    const agent_types = [_]AgentType{
        .Settler, .Explorer, .Builder, .Farmer, .Miner, .Scout
    };
    
    // Use crypto.random directly
    
    for (0..count) |i| {
        const x = random.uintLessThan(usize, width);
        const y = random.uintLessThan(usize, height);
        const agent_type = agent_types[random.uintLessThan(usize, agent_types.len)];
        const health = 100;
        const energy = 100;
        
        try agents.append(Agent.init(i, x, y, agent_type, health, energy));
    }
}

// Initialize the map with varied terrain
fn initializeMap(map: *Map) !void {
    const width = map.width;
    const height = map.height;
    
    // Default is Empty
    
    // Add some Grass (in roughly circular pattern in the middle left)
    const grass_center_x = width / 4;
    const grass_center_y = height / 2;
    const grass_radius = height / 3;
    
    // Add some Forest (in the upper right)
    const forest_center_x = width * 3 / 4;
    const forest_center_y = height / 3;
    const forest_radius = height / 4;
    
    // Add some Mountains (in the lower right)
    const mountain_center_x = width * 3 / 4;
    const mountain_center_y = height * 2 / 3;
    const mountain_radius = height / 5;
    
    // Add some Water (along the top)
    const water_y_level = height / 8;
    
    for (0..width) |x| {
        for (0..height) |y| {
            // Water along the top
            if (y < water_y_level) {
                map.setTerrain(x, y, .Water);
                continue;
            }
            
            // Grass in circular pattern
            const grass_dist_sq = (x -% grass_center_x) * (x -% grass_center_x) + 
                                  (y -% grass_center_y) * (y -% grass_center_y);
            if (grass_dist_sq < grass_radius * grass_radius) {
                map.setTerrain(x, y, .Grass);
                continue;
            }
            
            // Forest in circular pattern
            const forest_dist_sq = (x -% forest_center_x) * (x -% forest_center_x) + 
                                   (y -% forest_center_y) * (y -% forest_center_y);
            if (forest_dist_sq < forest_radius * forest_radius) {
                map.setTerrain(x, y, .Forest);
                continue;
            }
            
            // Mountains in circular pattern
            const mountain_dist_sq = (x -% mountain_center_x) * (x -% mountain_center_x) + 
                                     (y -% mountain_center_y) * (y -% mountain_center_y);
            if (mountain_dist_sq < mountain_radius * mountain_radius) {
                map.setTerrain(x, y, .Mountain);
                continue;
            }
        }
    }
}