const std = @import("std");
const testing = std.testing;
const agent_mod = @import("agent");
const Interaction = agent_mod.Interaction;
const InteractionType = agent_mod.InteractionType;
const Agent = agent_mod.Agent;

test "interaction type symbols" {
    try testing.expectEqual(@as(u8, 'G'), InteractionType.Greeting.getSymbol());
    try testing.expectEqual(@as(u8, 'T'), InteractionType.Trading.getSymbol());
    try testing.expectEqual(@as(u8, 'C'), InteractionType.Collaboration.getSymbol());
    try testing.expectEqual(@as(u8, 'E'), InteractionType.Teaching.getSymbol());
    try testing.expectEqual(@as(u8, 'R'), InteractionType.Resource.getSymbol());
}

test "interaction initialization" {
    const agent1 = Agent.init(1, 5, 5, .Explorer, 100, 100);
    const agent2 = Agent.init(2, 6, 5, .Settler, 90, 80);
    
    const interaction = Interaction.init(agent1, agent2, .Trading);
    
    try testing.expectEqual(@as(usize, 1), interaction.agent1_id);
    try testing.expectEqual(@as(usize, 2), interaction.agent2_id);
    try testing.expectEqual(InteractionType.Trading, interaction.type);
    try testing.expectEqual(@as(u8, 3), interaction.duration); // Default duration
}