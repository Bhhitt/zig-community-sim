// Low-level agent update micro-benchmark
// ------------------------------------------------------
// This file is intended for isolated profiling of agent
// movement and update logic, separate from the main
// simulation modules. It does NOT use the core simulation
// or agent data structures, and is meant for micro-benchmarking
// core movement code only. For full-system benchmarks, use
// src/benchmark.zig and `zig build benchmark`.
// ------------------------------------------------------

const std = @import("std");

// Movement pattern simplified for testing
const MovementPattern = struct {
    move_chance: u8 = 50,           // Base chance to move
    can_move_diagonally: bool = false,
    diagonal_chance: u8 = 0,        // Chance for diagonal movement
    can_double_step: bool = false,
    double_step_chance: u8 = 0,     // Chance for double step
    pattern_based: bool = false,    // Pattern-based movement
    spiral_movement: bool = false,  // Spiral movement
    home_seeking: bool = false,     // Home-seeking behavior
    home_seeking_chance: u8 = 0,    // Home-seeking chance
    tendency_to_stay: u8 = 0,       // Tendency to stay
    direction_change_rate: u8 = 50, // Direction change rate
    base_energy_cost: u8 = 2,       // Base energy cost
    // Directional bias
    directional_bias: struct {
        north: u8 = 25,
        south: u8 = 25,
        east: u8 = 25,
        west: u8 = 25,
    } = .{},
};

const AgentType = enum {
    Settler,
    Explorer,
    Builder,
    Farmer,
    Miner,
    Scout,
};

const Agent = struct {
    id: usize,
    x: f32,
    y: f32,
    type: AgentType,
    health: u8,
    energy: u8,
    speed: f32,
    seed: u64,

    pub fn update(self: *Agent) void {
        // Example: random walk with speed
        var prng = std.crypto.random;
        const dx = (prng.float(f32) - 0.5) * 2.0 * self.speed;
        const dy = (prng.float(f32) - 0.5) * 2.0 * self.speed;
        self.x += dx;
        self.y += dy;
        self.energy = if (self.energy > 0) self.energy - 1 else 0;
    }
};

const DEFAULT_AGENT_COUNT = 10_000;
const DEFAULT_ITERATIONS = 20_000;
const DEFAULT_THREAD_COUNT = 4;

fn runPerformanceTest(agents: []Agent, iterations: usize) void {
    const start_time = std.time.milliTimestamp();
    for (0..iterations) |_| {
        for (agents) |*agent| {
            agent.update();
        }
    }
    const end_time = std.time.milliTimestamp();
    std.debug.print("[Single-threaded] Performed {d} agent updates in {d} ms\n", .{agents.len * iterations, end_time - start_time});
}

fn runPerformanceTestMultiThreaded(agents: []Agent, iterations: usize, thread_count: usize) !void {
    const chunk_size = (agents.len + thread_count - 1) / thread_count;
    var threads: [DEFAULT_THREAD_COUNT]std.Thread = undefined;
    var results: [DEFAULT_THREAD_COUNT]usize = undefined;
    const start_time = std.time.milliTimestamp();
    for (0..thread_count) |t| {
        const start = t * chunk_size;
        const end = @min(start + chunk_size, agents.len);
        if (start >= end) {
            results[t] = 0;
            continue;
        }
        threads[t] = try std.Thread.spawn(.{}, struct {
            fn run(slice: []Agent, thread_iterations: usize, results_ptr: *usize) void {
                var sum: usize = 0;
                for (0..thread_iterations) |_| {
                    for (slice) |*agent| {
                        agent.update();
                        sum += agent.energy;
                    }
                }
                results_ptr.* = sum;
            }
        }.run, .{agents[start..end], iterations, &results[t]});
    }
    for (0..thread_count) |t| {
        threads[t].join();
    }
    const end_time = std.time.milliTimestamp();
    var total_sum: usize = 0;
    for (results) |s| total_sum += s;
    std.debug.print("[Multi-threaded] Performed {d} agent updates in {d} ms (energy sum: {d})\n", .{agents.len * iterations, end_time - start_time, total_sum});
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    const agent_count = DEFAULT_AGENT_COUNT;
    const iterations = DEFAULT_ITERATIONS;
    const thread_count = DEFAULT_THREAD_COUNT;
    var agents = try gpa.alloc(Agent, agent_count);
    defer gpa.free(agents);
    for (0..agents.len) |i| {
        agents[i] = Agent{
            .id = i,
            .x = 0.0,
            .y = 0.0,
            .type = AgentType.Settler,
            .health = 100,
            .energy = 100,
            .speed = 0.7,
            .seed = @as(u64, i) * 123456789,
        };
    }
    runPerformanceTest(agents[0..], iterations);
    try runPerformanceTestMultiThreaded(agents[0..], iterations, thread_count);
}
