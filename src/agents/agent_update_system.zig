const std = @import("std");
const Agent = @import("agent").Agent;
const Map = @import("map").Map;
const TerrainEffect = @import("terrain_effects").TerrainEffect;
const AgentType = @import("agent_type").AgentType;

const max_energy = 100;
const max_health = 100;
const health_regen = 1;

pub fn updateAgent(agent: *Agent, map: *const Map) void {
    // Debug: Print position before update
    std.debug.print("[AgentUpdateSystem] Before: id={} type={s} pos=({}, {})\n", .{ agent.id, @tagName(agent.type), agent.x, agent.y });
    // Get movement pattern for this agent type
    const movement_pattern = agent.type.getMovementPattern();
    
    // Calculate movement direction
    const movement = agent.calculateMovement(movement_pattern);
    const dx = movement.dx;
    const dy = movement.dy;
    
    // Get current terrain the agent is on
    const current_terrain = map.getTerrainAt(agent.x, agent.y);
    const terrain_effects = TerrainEffect.forAgentAndTerrain(agent.type, current_terrain);
    
    // Apply terrain energy gain
    if (terrain_effects.energy_gain > 0) {
        agent.energy = @min(agent.energy + terrain_effects.energy_gain, max_energy);
    }
    
    // Apply health effects from current terrain
    agent.applyHealthEffects(terrain_effects.health_effect);
    
    // Check if agent can move based on terrain
    const can_move = blk: {
        // No movement planned
        if (dx == 0 and dy == 0) break :blk true;
        
        // Calculate new position with boundary checks
        const new_pos = agent.calculateNewPosition(dx, dy);
        
        // Get terrain at the new position and check movement probability
        const target_terrain = map.getTerrainAt(new_pos.x, new_pos.y);
        const target_effects = TerrainEffect.forAgentAndTerrain(agent.type, target_terrain);
        
        break :blk @mod(agent.seed, 100) < target_effects.movement_prob;
    };
    
    // Apply movement if allowed
    if (can_move) {
        // Calculate new position
        const new_pos = agent.calculateNewPosition(dx, dy);
        agent.x = new_pos.x;
        agent.y = new_pos.y;
        
        // Get new terrain for energy cost calculation
        const new_terrain = map.getTerrainAt(agent.x, agent.y);
        const new_effects = TerrainEffect.forAgentAndTerrain(agent.type, new_terrain);
        
        // Calculate and apply energy cost
        const energy_cost = agent.calculateEnergyCost(
            dx, dy, 
            movement_pattern.base_energy_cost, 
            new_effects.movement_cost
        );
        
        // Apply energy cost, ensuring we don't underflow
        if (agent.energy > energy_cost) {
            agent.energy -= energy_cost;
        } else {
            agent.energy = 0;
        }
    }
    // Debug: Print position after update
    std.debug.print("[AgentUpdateSystem] After: id={} type={s} pos=({}, {})\n", .{ agent.id, @tagName(agent.type), agent.x, agent.y });
}
