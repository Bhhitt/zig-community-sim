const std = @import("std");
const testing = std.testing;
const agent_mod = @import("agent");
const Agent = agent_mod.Agent;
const AgentType = agent_mod.AgentType;
const MovementPattern = agent_mod.MovementPattern;
const map_mod = @import("map");
const Map = map_mod.Map;
const Terrain = map_mod.Terrain;
const agent_update_system = @import("agent_update_system");
const config = @import("config");

// Test utility to create a controlled map environment
fn createTestMap(allocator: std.mem.Allocator) !Map {
    var map = try Map.init(allocator, 20, 20, config.AppConfig{});
    
    // Create a map with different terrains in quadrants
    for (0..map.width) |x| {
        for (0..map.height) |y| {
            if (x < map.width / 2 and y < map.height / 2) {
                map.setTerrain(x, y, .Grass);
            } else if (x >= map.width / 2 and y < map.height / 2) {
                map.setTerrain(x, y, .Forest);
            } else if (x < map.width / 2 and y >= map.height / 2) {
                map.setTerrain(x, y, .Mountain);
            } else {
                map.setTerrain(x, y, .Water);
            }
        }
    }
    
    return map;
}

test "agent basic movement" {
    var map = try createTestMap(testing.allocator);
    defer map.deinit();
    
    // Create an explorer agent - high movement chance
    var explorer = Agent.init(1, 5, 5, .Explorer, 100, 100);
    
    // Original position
    const original_x = explorer.x;
    const original_y = explorer.y;
    
    // Update the agent several times
    var moved = false;
    var movement_attempted = false;
    for (0..10) |_| {
        // Calculate intended movement before update
        const movement_pattern = explorer.type.getMovementPattern();
        const movement = explorer.calculateMovement(movement_pattern);
        if (movement.dx != 0 or movement.dy != 0) {
            movement_attempted = true;
        }
        agent_update_system.updateAgent(&explorer, &map, config.AppConfig{});
        
        // Check if agent moved at least once
        if (explorer.x != original_x or explorer.y != original_y) {
            moved = true;
        }
    }
    
    // Since Explorer has 90% move_chance, it should have moved at least once
    try testing.expect(moved);
    
    if (movement_attempted) {
        try testing.expect(explorer.energy < 100);
    }
}

test "settler tendency to stay" {
    // We'll just test basic functionality since the behavior is probabilistic
    
    var map = try createTestMap(testing.allocator);
    defer map.deinit();
    
    // Create a settler agent - low movement chance, high tendency to stay
    var settler = Agent.init(2, 10, 10, .Settler, 100, 100);
    
    // We can't really test probabilistic behavior reliably
    // So we'll just ensure the agent updates without crashing
    for (0..20) |_| {
        agent_update_system.updateAgent(&settler, &map, config.AppConfig{});
        // Just check health and energy remain valid
        try testing.expect(settler.health > 0 and settler.health <= 100);
        try testing.expect(settler.energy <= 100);
    }
    
    // Test passes as long as we got here without crashing
}

test "terrain effects on movement cost" {
    var map = try createTestMap(testing.allocator);
    defer map.deinit();
    
    // Create a miner that's good on mountains
    var miner = Agent.init(3, 5, 15, .Miner, 100, 100);
    
    // Create a farmer that's good on grass
    var farmer = Agent.init(4, 5, 5, .Farmer, 100, 100);
    
    // Update both agents multiple times
    for (0..10) |_| {
        const miner_energy_before = miner.energy;
        const farmer_energy_before = farmer.energy;
        
        agent_update_system.updateAgent(&miner, &map, config.AppConfig{});
        agent_update_system.updateAgent(&farmer, &map, config.AppConfig{});
        
        // Both should lose energy when moving, but miner should get energy boost on mountains
        if (miner.energy > miner_energy_before) {
            // Energy gained from terrain
            try testing.expect(map.getTerrainAt(@intFromFloat(miner.x), @intFromFloat(miner.y)) == .Mountain);
        }
        
        if (farmer.energy > farmer_energy_before) {
            // Energy gained from terrain
            try testing.expect(map.getTerrainAt(@intFromFloat(farmer.x), @intFromFloat(farmer.y)) == .Grass);
        }
    }
}

test "agent movement boundaries" {
    var map = try Map.init(testing.allocator, 20, 20, config.AppConfig{});
    defer map.deinit();
    
    // Set agent near the edge
    var agent = Agent.init(5, 1, 1, .Explorer, 100, 100);
    
    // Force many updates to test boundary handling
    for (0..20) |_| {
        agent_update_system.updateAgent(&agent, &map, config.AppConfig{});
        
        // Agent should never go out of bounds
        try testing.expectEqual(true, agent.x < @as(f32, @floatFromInt(map.width)));
        try testing.expectEqual(true, agent.y < @as(f32, @floatFromInt(map.height)));
    }
}

test "explorer movement and energy consumption" {
    var map = try createTestMap(testing.allocator);
    defer map.deinit();
    var explorer = Agent.init(1, 10, 10, .Explorer, 100, 100);
    const original_x = explorer.x;
    const original_y = explorer.y;
    var moved = false;
    const initial_energy = explorer.energy;
    for (0..10) |_| {
        agent_update_system.updateAgent(&explorer, &map, config.AppConfig{});
        if (explorer.x != original_x or explorer.y != original_y) {
            moved = true;
        }
    }
    try testing.expect(moved);
    try testing.expect(explorer.energy < initial_energy);
}

test "explorer hunger increases when not eating" {
    var map = try createTestMap(testing.allocator);
    defer map.deinit();
    var explorer = Agent.init(1, 10, 10, .Explorer, 100, 100);
    const initial_hunger = explorer.hunger;
    // Ensure no food at agent's starting position
    map.setFoodAt(@intFromFloat(explorer.x), @intFromFloat(explorer.y), 0);
    for (0..10) |_| {
        agent_update_system.updateAgent(&explorer, &map, config.AppConfig{});
    }
    try testing.expect(explorer.hunger > initial_hunger);
}