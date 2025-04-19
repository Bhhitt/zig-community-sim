const std = @import("std");
const Agent = @import("agent").Agent;
const Map = @import("map").Map;
const agent_update_system = @import("agent_update_system");
const Terrain = @import("terrain").Terrain;

pub fn main() void {}

// Test perception logic for nearest food and nearby agent count
pub fn test_perception() !void {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();

    // Place food at (5,5)
    map.setFoodAt(5, 5, 1);

    // Create agents
    var agents = [_]Agent{
        Agent.init(0, 2, 2, .Settler, 100, 100), // Test subject
        Agent.init(1, 3, 2, .Settler, 100, 100), // Nearby agent
        Agent.init(2, 8, 8, .Settler, 100, 100), // Far agent
    };

    // Test subject is agents[0]
    agent_update_system.updateAgentPerception(&agents[0], agents[0..], &map, 5);

    // Check nearest food
    try std.testing.expect(agents[0].nearest_food_x != null and agents[0].nearest_food_y != null);
    try std.testing.expect(agents[0].nearest_food_x.? == 5 and agents[0].nearest_food_y.? == 5);
    try std.testing.expect(agents[0].nearest_food_dist != null);

    // Check nearby agent count (should count agent 1, but not agent 2)
    try std.testing.expect(agents[0].nearby_agent_count == 1);
}

// Additional edge case tests for perception

test "perception: no food in range sets nearest_food to null" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    var agents = [_]Agent{
        Agent.init(0, 2, 2, .Settler, 100, 100),
    };
    agent_update_system.updateAgentPerception(&agents[0], agents[0..], &map, 3);
    try std.testing.expect(agents[0].nearest_food_x == null and agents[0].nearest_food_y == null);
    try std.testing.expect(agents[0].nearest_food_dist == null);
}

test "perception: multiple foods, nearest is chosen" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    map.setFoodAt(5, 5, 1); // farther
    map.setFoodAt(3, 2, 1); // nearer
    var agents = [_]Agent{
        Agent.init(0, 2, 2, .Settler, 100, 100),
    };
    agent_update_system.updateAgentPerception(&agents[0], agents[0..], &map, 5);
    try std.testing.expect(agents[0].nearest_food_x.? == 3 and agents[0].nearest_food_y.? == 2);
}

test "perception: food at edge of radius is included" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    // Place food at distance exactly 3 from (2,2)
    map.setFoodAt(5, 2, 1); // dx=3, dy=0
    var agents = [_]Agent{
        Agent.init(0, 2, 2, .Settler, 100, 100),
    };
    agent_update_system.updateAgentPerception(&agents[0], agents[0..], &map, 3);
    try std.testing.expect(agents[0].nearest_food_x.? == 5 and agents[0].nearest_food_y.? == 2);
}

test "perception: agent just outside radius is not counted" {
    const allocator = std.testing.allocator;
    var map = try Map.init(allocator, 10, 10, .{ .food_spawn_chance = 0 });
    defer map.deinit();
    var agents = [_]Agent{
        Agent.init(0, 2, 2, .Settler, 100, 100), // subject
        Agent.init(1, 6, 2, .Settler, 100, 100), // exactly 4 away (outside radius 3)
    };
    agent_update_system.updateAgentPerception(&agents[0], agents[0..], &map, 3);
    try std.testing.expect(agents[0].nearby_agent_count == 0);
}

test "agent perception finds nearest food and counts nearby agents" {
    try test_perception();
}
