const std = @import("std");
const testing = std.testing;
const agent_mod = @import("agent");
const Agent = agent_mod.Agent;
const AgentType = agent_mod.AgentType;
const MovementPattern = agent_mod.MovementPattern;
const map_mod = @import("map");
const Map = map_mod.Map;
const Terrain = map_mod.Terrain;

// Test utility to create a controlled map environment
fn createTestMap(allocator: std.mem.Allocator) !Map {
    var map = try Map.init(allocator, 20, 20);
    
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
    for (0..10) |_| {
        explorer.update(&map);
        
        // Check if agent moved at least once
        if (explorer.x != original_x or explorer.y != original_y) {
            moved = true;
            break;
        }
    }
    
    // Since Explorer has 90% move_chance, it should have moved at least once
    try testing.expect(moved);
    
    // Verify energy was consumed (should be less than 100 after moving)
    try testing.expect(explorer.energy < 100);
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
        settler.update(&map);
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
        
        miner.update(&map);
        farmer.update(&map);
        
        // Both should lose energy when moving, but miner should get energy boost on mountains
        if (miner.energy > miner_energy_before) {
            // Energy gained from terrain
            try testing.expect(map.getTerrainAt(miner.x, miner.y) == .Mountain);
        }
        
        if (farmer.energy > farmer_energy_before) {
            // Energy gained from terrain
            try testing.expect(map.getTerrainAt(farmer.x, farmer.y) == .Grass);
        }
    }
}

test "agent movement boundaries" {
    var map = try Map.init(testing.allocator, 20, 20);
    defer map.deinit();
    
    // Set agent near the edge
    var agent = Agent.init(5, 1, 1, .Explorer, 100, 100);
    
    // Force many updates to test boundary handling
    for (0..20) |_| {
        agent.update(&map);
        
        // Agent should never go out of bounds
        try testing.expectEqual(true, agent.x < map.width);
        try testing.expectEqual(true, agent.y < map.height);
    }
}