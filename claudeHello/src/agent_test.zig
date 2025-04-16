const std = @import("std");
const testing = std.testing;
const Agent = @import("agent.zig").Agent;
const AgentType = @import("agent.zig").AgentType;

test "Agent init" {
    const agent = Agent.init(1, 5, 10, .Settler, 100, 80);
    
    try testing.expectEqual(@as(usize, 1), agent.id);
    try testing.expectEqual(@as(usize, 5), agent.x);
    try testing.expectEqual(@as(usize, 10), agent.y);
    try testing.expectEqual(AgentType.Settler, agent.type);
    try testing.expectEqual(@as(u8, 100), agent.health);
    try testing.expectEqual(@as(u8, 80), agent.energy);
}

test "Agent getSymbol" {
    var agent = Agent.init(1, 0, 0, .Settler, 100, 100);
    try testing.expectEqual(@as(u8, 'S'), agent.getSymbol());
    
    agent.type = .Explorer;
    try testing.expectEqual(@as(u8, 'E'), agent.getSymbol());
    
    agent.type = .Builder;
    try testing.expectEqual(@as(u8, 'B'), agent.getSymbol());
}

test "Agent update - boundary checks" {
    // Test agent at origin
    var agent = Agent.init(1, 0, 0, .Settler, 100, 100);
    
    // Run multiple updates and verify agent can't move into negative coordinates
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        agent.update();
        try testing.expect(agent.x >= 0);
        try testing.expect(agent.y >= 0);
    }
    
    // Test that energy decreases
    try testing.expect(agent.energy < 100);
}