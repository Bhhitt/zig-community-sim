const std = @import("std");
const testing = std.testing;
const Simulation = @import("simulation.zig").Simulation;
const AgentType = @import("agent.zig").AgentType;

test "Simulation init" {
    const allocator = testing.allocator;
    var sim = try Simulation.init(allocator, 15, 10);
    defer sim.deinit();
    
    try testing.expectEqual(@as(usize, 15), sim.map.width);
    try testing.expectEqual(@as(usize, 10), sim.map.height);
    try testing.expectEqual(@as(usize, 0), sim.agents.items.len);
    try testing.expectEqual(@as(usize, 0), sim.next_agent_id);
}

test "Simulation spawn agent" {
    const allocator = testing.allocator;
    var sim = try Simulation.init(allocator, 15, 10);
    defer sim.deinit();
    
    try sim.spawnAgent(.{ .x = 5, .y = 5, .type = .Settler });
    try testing.expectEqual(@as(usize, 1), sim.agents.items.len);
    try testing.expectEqual(@as(usize, 1), sim.next_agent_id);
    
    try sim.spawnAgent(.{ .x = 8, .y = 3, .type = .Explorer, .health = 80, .energy = 120 });
    try testing.expectEqual(@as(usize, 2), sim.agents.items.len);
    try testing.expectEqual(@as(usize, 2), sim.next_agent_id);
    
    // Check agent values
    try testing.expectEqual(@as(usize, 0), sim.agents.items[0].id);
    try testing.expectEqual(@as(usize, 5), sim.agents.items[0].x);
    try testing.expectEqual(@as(usize, 5), sim.agents.items[0].y);
    try testing.expectEqual(AgentType.Settler, sim.agents.items[0].type);
    try testing.expectEqual(@as(u8, 100), sim.agents.items[0].health);
    try testing.expectEqual(@as(u8, 100), sim.agents.items[0].energy);
    
    try testing.expectEqual(@as(usize, 1), sim.agents.items[1].id);
    try testing.expectEqual(@as(usize, 8), sim.agents.items[1].x);
    try testing.expectEqual(@as(usize, 3), sim.agents.items[1].y);
    try testing.expectEqual(AgentType.Explorer, sim.agents.items[1].type);
    try testing.expectEqual(@as(u8, 80), sim.agents.items[1].health);
    try testing.expectEqual(@as(u8, 120), sim.agents.items[1].energy);
}

test "Simulation update" {
    const allocator = testing.allocator;
    var sim = try Simulation.init(allocator, 15, 10);
    defer sim.deinit();
    
    // Use Explorer type which always moves in our implementation
    try sim.spawnAgent(.{ .x = 5, .y = 5, .type = .Explorer });
    
    // Force a time delay to ensure movement happens
    std.time.sleep(10 * std.time.ns_per_ms);
    
    // Update the simulation
    try sim.update();
    
    // Check that position changed (Explorers always move)
    // or at least energy decreased
    const moved = sim.agents.items[0].x != 5 or sim.agents.items[0].y != 5;
    const energy_changed = sim.agents.items[0].energy < 100;
    
    try testing.expect(moved or energy_changed);
}

test "Simulation threaded update with many agents" {
    const allocator = testing.allocator;
    var sim = try Simulation.init(allocator, 20, 20);
    defer sim.deinit();
    
    // Add many agents to trigger the threaded code path
    const num_agents = 20; // More than thread_count * 2
    var i: usize = 0;
    while (i < num_agents) : (i += 1) {
        const agent_type = switch (@mod(i, 3)) {
            0 => AgentType.Settler,
            1 => AgentType.Explorer,
            2 => AgentType.Builder,
            else => AgentType.Settler,
        };
        
        try sim.spawnAgent(.{
            .x = @mod(i, 10) + 5,
            .y = @divTrunc(i, 10) + 5,
            .type = agent_type,
        });
    }
    
    // Update the simulation using threads
    try sim.update();
    
    // Verify all agents are still within map bounds
    for (sim.agents.items) |agent| {
        try testing.expect(agent.x < sim.map.width);
        try testing.expect(agent.y < sim.map.height);
    }
}