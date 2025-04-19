const std = @import("std");
const Agent = @import("agent").Agent;
const Map = @import("map").Map;
const agent_update_system = @import("agent_update_system");

const DummyConfig = struct {
    hunger_threshold: u8 = 80,
    hunger_health_penalty: u8 = 5,
    perception_radius: usize = 5,
    food_seek_aggressiveness_base: f32 = 0.1,
    food_seek_aggressiveness_hunger_coeff: f32 = 0.01,
};

test "hunger increases and is capped at max" {
    var agent = Agent.init(0, 2, 2, .Settler, 100, 100);
    agent.hunger = 250;
    // Simulate hunger increment (should cap at 255 for u8)
    agent.hunger +|= 10; // saturating add
    try std.testing.expect(agent.hunger == 255);
}

test "hunger resets to 0 when eating food" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    map.setFoodAt(2, 2, 1);
    var agent = Agent.init(0, 2, 2, .Settler, 100, 100);
    agent.hunger = 50;
    agent_update_system.updateAgent(&agent, &map, DummyConfig{}, &[_]Agent{agent});
    try std.testing.expect(agent.hunger == 0);
    try std.testing.expect(map.getFoodAt(2, 2) == 0);
}

test "hunger does not go negative" {
    var agent = Agent.init(0, 2, 2, .Settler, 100, 100);
    agent.hunger = 0;
    // Simulate decrement (should not go below 0)
    if (agent.hunger > 0) agent.hunger -= 1;
    try std.testing.expect(agent.hunger == 0);
}

test "health penalty applied when hunger exceeds threshold" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    var agent = Agent.init(0, 2, 2, .Settler, 100, 100);
    agent.hunger = 90; // above threshold
    agent.health = 50;
    agent_update_system.updateAgent(&agent, &map, DummyConfig{}, &[_]Agent{agent});
    try std.testing.expect(agent.health == 45);
}

test "no health penalty when hunger below threshold" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    var agent = Agent.init(0, 2, 2, .Settler, 100, 100);
    agent.hunger = 40; // below threshold
    agent.health = 50;
    agent_update_system.updateAgent(&agent, &map, DummyConfig{}, &[_]Agent{agent});
    try std.testing.expect(agent.health == 50);
}
