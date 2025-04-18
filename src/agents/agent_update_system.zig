const std = @import("std");
const Agent = @import("agent").Agent;
const Map = @import("map").Map;
const TerrainEffect = @import("terrain_effects").TerrainEffect;
const AgentType = @import("agent_type").AgentType;

const max_energy = 100;
const max_health = 100;
const health_regen = 1;

pub fn updateAgent(agent: *Agent, map: *Map, config: anytype) void {
    // Debug: Print position before update
    // std.debug.print("[AgentUpdateSystem] Before: id={} type={s} pos=({}, {})\n", .{ agent.id, @tagName(agent.type), agent.x, agent.y });
    // Get movement pattern for this agent type
    const movement_pattern = agent.type.getMovementPattern();
    
    // Calculate movement direction
    const movement = agent.calculateMovement(movement_pattern);
    // Scale movement by agent speed for smooth movement
    const dx = movement.dx * agent.speed;
    const dy = movement.dy * agent.speed;
    
    // Get current terrain the agent is on
    const current_terrain = map.getTerrainAt(@intFromFloat(agent.x), @intFromFloat(agent.y));
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
        const target_terrain = map.getTerrainAt(@intFromFloat(new_pos.x), @intFromFloat(new_pos.y));
        const target_effects = TerrainEffect.forAgentAndTerrain(agent.type, target_terrain);
        
        break :blk @mod(agent.seed, 100) < target_effects.movement_prob;
    };
    
    // Always consume energy on movement attempt, even if move is blocked
    var attempted_move = false;
    if (can_move) {
        // Calculate new position
        const new_pos = agent.calculateNewPosition(dx, dy);
        agent.x = new_pos.x;
        agent.y = new_pos.y;
        attempted_move = true;
    } else if (dx != 0 or dy != 0) {
        attempted_move = true;
    }
    if (attempted_move) {
        // Use terrain at current or attempted position for cost
        const cost_terrain = map.getTerrainAt(@intFromFloat(agent.x), @intFromFloat(agent.y));
        const cost_effects = TerrainEffect.forAgentAndTerrain(agent.type, cost_terrain);
        const energy_cost = agent.calculateEnergyCost(
            dx, dy, 
            movement_pattern.base_energy_cost, 
            cost_effects.movement_cost
        );
        if (agent.energy > energy_cost) {
            agent.energy -= energy_cost;
        } else {
            agent.energy = 0;
        }
    }
    
    // Hunger system: increase hunger every step
    if (agent.hunger < 100) {
        agent.hunger += 1;
    }
    // If agent is on food, eat and reduce hunger, remove food from map
    if (map.getFoodAt(@intFromFloat(agent.x), @intFromFloat(agent.y)) > 0) {
        agent.hunger = 0; // Fully satiated
        map.setFoodAt(@intFromFloat(agent.x), @intFromFloat(agent.y), 0);
    }
    // Health penalty for high hunger (configurable)
    if (agent.hunger >= config.hunger_threshold) {
        if (agent.health > 0) {
            agent.health -= config.hunger_health_penalty;
        }
    }
    
    // Debug: Print position after update
    // std.debug.print("[AgentUpdateSystem] After: id={} type={s} pos=({}, {})\n", .{ agent.id, @tagName(agent.type), agent.x, agent.y });
}
