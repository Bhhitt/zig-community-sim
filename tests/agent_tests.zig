const std = @import("std");
const testing = std.testing;
const agent_mod = @import("agent");
const Agent = agent_mod.Agent;
const AgentType = agent_mod.AgentType;
const TerrainEffect = agent_mod.TerrainEffect;
const map_mod = @import("map");
const Map = map_mod.Map;
const Terrain = map_mod.Terrain;

test "agent initialization" {
    const agent = Agent.init(1, 10, 10, .Explorer, 100, 100);
    try testing.expectEqual(@as(usize, 1), agent.id);
    try testing.expectEqual(@as(usize, 10), agent.x);
    try testing.expectEqual(@as(usize, 10), agent.y);
    try testing.expectEqual(AgentType.Explorer, agent.type);
    try testing.expectEqual(@as(u8, 100), agent.health);
    try testing.expectEqual(@as(u8, 100), agent.energy);
}

test "agent symbol" {
    const agent = Agent.init(1, 10, 10, .Explorer, 100, 100);
    try testing.expectEqual(@as(u8, 'E'), agent.getSymbol());
    
    const settler = Agent.init(2, 5, 5, .Settler, 100, 100);
    try testing.expectEqual(@as(u8, 'S'), settler.getSymbol());
    
    const builder = Agent.init(3, 5, 5, .Builder, 100, 100);
    try testing.expectEqual(@as(u8, 'B'), builder.getSymbol());
}

test "agent type movement patterns" {
    // Test that each agent type returns the correct movement pattern
    const settler_pattern = AgentType.Settler.getMovementPattern();
    try testing.expectEqual(@as(u8, 30), settler_pattern.move_chance);
    try testing.expectEqual(false, settler_pattern.can_move_diagonally);
    try testing.expectEqual(false, settler_pattern.can_double_step);
    try testing.expectEqual(@as(u8, 2), settler_pattern.base_energy_cost);

    const explorer_pattern = AgentType.Explorer.getMovementPattern();
    try testing.expectEqual(@as(u8, 90), explorer_pattern.move_chance);
    try testing.expectEqual(false, explorer_pattern.can_move_diagonally);
    try testing.expectEqual(true, explorer_pattern.can_double_step);
    try testing.expectEqual(@as(u8, 14), explorer_pattern.double_step_chance);
    try testing.expectEqual(@as(u8, 1), explorer_pattern.base_energy_cost);
}

test "terrain effects" {
    // Test terrain effects for different agent types
    const settler_grass = TerrainEffect.forAgentAndTerrain(.Settler, .Grass);
    try testing.expectEqual(@as(u8, 0), settler_grass.movement_cost);
    try testing.expectEqual(@as(u8, 100), settler_grass.movement_prob);
    try testing.expectEqual(@as(u8, 1), settler_grass.energy_gain);
    try testing.expectEqual(@as(i8, 1), settler_grass.health_effect);
    
    const miner_mountain = TerrainEffect.forAgentAndTerrain(.Miner, .Mountain);
    try testing.expectEqual(@as(u8, 1), miner_mountain.movement_cost);
    try testing.expectEqual(@as(u8, 90), miner_mountain.movement_prob);
    try testing.expectEqual(@as(u8, 2), miner_mountain.energy_gain);
    try testing.expectEqual(@as(i8, 0), miner_mountain.health_effect);
    
    const farmer_water = TerrainEffect.forAgentAndTerrain(.Farmer, .Water);
    try testing.expectEqual(@as(u8, 4), farmer_water.movement_cost);
    try testing.expectEqual(@as(u8, 30), farmer_water.movement_prob);
    try testing.expectEqual(@as(u8, 1), farmer_water.energy_gain);
    try testing.expectEqual(@as(i8, 0), farmer_water.health_effect);
}