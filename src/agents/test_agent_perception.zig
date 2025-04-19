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

test "agent perception finds nearest food and counts nearby agents" {
    try test_perception();
}
