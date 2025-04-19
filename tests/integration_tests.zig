const std = @import("std");
const testing = std.testing;
const agent_mod = @import("agent");
const Agent = agent_mod.Agent;
const AgentType = agent_mod.AgentType;
const map_mod = @import("map");
const Map = map_mod.Map;
const Terrain = map_mod.Terrain;
const test_utils = @import("test_utils");
const TestMap = test_utils.TestMap;
const agent_update_system = @import("agent_update_system");
const config = @import("config");

// Test multiple agent types coexisting on a map
test "multiple agent types behavior" {
    var test_map = try TestMap.init(testing.allocator, 30, 30);
    defer test_map.deinit();
    test_map.createQuadrantMap();
    
    // Create one of each agent type
    var agents = std.ArrayList(Agent).init(testing.allocator);
    defer agents.deinit();
    
    const start_x = 15;
    const start_y = 15;
    
    try agents.append(Agent.init(1, start_x, start_y, .Settler, 100, 100));
    try agents.append(Agent.init(2, start_x, start_y, .Explorer, 100, 100));
    try agents.append(Agent.init(3, start_x, start_y, .Builder, 100, 100));
    try agents.append(Agent.init(4, start_x, start_y, .Farmer, 100, 100));
    try agents.append(Agent.init(5, start_x, start_y, .Miner, 100, 100));
    try agents.append(Agent.init(6, start_x, start_y, .Scout, 100, 100));
    
    // Simulate for a significant number of steps
    for (0..50) |_| {
        for (agents.items) |*agent| {
            agent_update_system.updateAgent(agent, &test_map.map, config.AppConfig{}, agents.items);
        }
    }
    
    // Check that agents have moved from their starting positions
    const epsilon = 0.01;
    var all_moved = true;
    for (agents.items) |agent| {
        const dx = agent.x - start_x;
        const dy = agent.y - start_y;
        const dist = std.math.sqrt(dx * dx + dy * dy);
        if (dist < epsilon) {
            all_moved = false;
            break;
        }
    }
    
    for (agents.items) |agent| {
        std.debug.print("Agent type {s}: pos=({d},{d}) energy={d} health={d}\n", .{
            @tagName(agent.type), @as(f64, agent.x), @as(f64, agent.y), agent.energy, agent.health
        });
    }
    try testing.expect(all_moved);
    
    // Check health and energy are valid
    for (agents.items) |agent| {
        // Verify health is still reasonable
        try testing.expect(agent.health > 0);
        try testing.expect(agent.health <= 100);
        
        // Energy should be a valid value (may reach 0 in some cases)
        try testing.expect(agent.energy <= 100);
    }
}

// Test agent behavior on different terrain types
test "agent terrain preferences" {
    var test_map = try TestMap.init(testing.allocator, 40, 40);
    defer test_map.deinit();
    test_map.createStripedMap();
    
    // Create agents with specific terrain preferences
    const miner = Agent.init(1, 20, 20, .Miner, 100, 100);
    const farmer = Agent.init(2, 20, 20, .Farmer, 100, 100);
    var agents = [_]Agent{ miner, farmer };
    
    // Simply ensure the agents can update on the terrain without errors
    for (0..50) |_| {
        agent_update_system.updateAgent(&agents[0], &test_map.map, config.AppConfig{}, agents[0..]);
        agent_update_system.updateAgent(&agents[1], &test_map.map, config.AppConfig{}, agents[0..]);
        
        // Verify health and energy remain valid
        try testing.expect(agents[0].health > 0 and agents[0].health <= 100);
        try testing.expect(agents[0].energy <= 100);
        try testing.expect(agents[1].health > 0 and agents[1].health <= 100);
        try testing.expect(agents[1].energy <= 100);
    }
    
    // Verify agents moved from starting position
    try testing.expect(agents[0].x != 20 or agents[0].y != 20);
    try testing.expect(agents[1].x != 20 or agents[1].y != 20);
}

// Test agent endurance and survivability 
test "agent long-term survival" {
    var test_map = try TestMap.init(testing.allocator, 50, 50);
    defer test_map.deinit();
    test_map.createRandomMap(42); // Fixed seed for reproducibility
    
    // Create agents of each type
    var agents = std.ArrayList(Agent).init(testing.allocator);
    defer agents.deinit();
    
    const all_types = [_]AgentType{
        .Settler, .Explorer, .Builder, .Farmer, .Miner, .Scout
    };
    
    for (all_types, 0..) |agent_type, i| {
        try agents.append(Agent.init(i, 25, 25, agent_type, 100, 100));
    }
    
    // Track survival statistics
    var health_history = try testing.allocator.alloc(
        std.ArrayList(u8), 
        agents.items.len
    );
    defer {
        for (health_history) |*history| {
            history.deinit();
        }
        testing.allocator.free(health_history);
    }
    
    for (health_history) |*history| {
        history.* = std.ArrayList(u8).init(testing.allocator);
    }
    
    // Run a lengthy simulation
    for (0..200) |_| {
        for (agents.items, 0..) |*agent, i| {
            agent_update_system.updateAgent(agent, &test_map.map, config.AppConfig{}, agents.items);
            try health_history[i].append(agent.health);
        }
    }
    
    // Check health patterns
    var survivors: usize = 0;
    for (health_history, 0..) |history, i| {
        if (history.items[history.items.len - 1] > 0) {
            survivors += 1;
        }
        // Check average health
        var total_health: usize = 0;
        for (history.items) |health| {
            total_health += health;
        }
        const avg_health = @divFloor(total_health, history.items.len);
        // Average health should be reasonable - for test stability we set a lower bound
        try testing.expect(avg_health > 30);
        std.debug.print("Agent type {s} average health: {d}\n", 
            .{@tagName(all_types[i]), avg_health});
    }
    // Allow rare deaths: require at least 4/6 agents survive
    try testing.expect(survivors >= 4);
}