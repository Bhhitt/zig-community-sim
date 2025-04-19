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
    
    // --- Smooth continuous movement ---
    // Calculate target direction as before
    const movement = agent.calculateMovement(movement_pattern);
    const target_dx = movement.dx * agent.speed;
    const target_dy = movement.dy * agent.speed;
    // If agent.smoothness > 0, interpolate velocity
    if (agent.smoothness > 0.0) {
        // Smoothly steer velocity toward target direction
        agent.vx = agent.vx * agent.smoothness + target_dx * (1.0 - agent.smoothness);
        agent.vy = agent.vy * agent.smoothness + target_dy * (1.0 - agent.smoothness);
        // Cap velocity to agent.speed
        const vlen = @sqrt(agent.vx * agent.vx + agent.vy * agent.vy);
        if (vlen > agent.speed) {
            agent.vx = agent.vx / vlen * agent.speed;
            agent.vy = agent.vy / vlen * agent.speed;
        }
    } else {
        // No smoothness: instant direction change
        agent.vx = target_dx;
        agent.vy = target_dy;
    }
    // Update position
    agent.x += agent.vx;
    agent.y += agent.vy;
    // --- End smooth movement ---
    
    // Clamp agent.x and agent.y to valid map bounds before using @intFromFloat
    const map_width_f = @as(f32, @floatFromInt(map.width - 1));
    const map_height_f = @as(f32, @floatFromInt(map.height - 1));
    if (agent.x < 0) {
        agent.x = 0;
    } else if (agent.x > map_width_f) {
        agent.x = map_width_f;
    }
    if (agent.y < 0) {
        agent.y = 0;
    } else if (agent.y > map_height_f) {
        agent.y = map_height_f;
    }
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
        if (agent.vx == 0 and agent.vy == 0) break :blk true;
        
        // Calculate new position with boundary checks
        const new_pos = agent.calculateNewPosition(agent.vx, agent.vy);
        
        // Clamp new position to valid map bounds before using @intFromFloat
        var clamped_new_x = new_pos.x;
        var clamped_new_y = new_pos.y;
        if (clamped_new_x < 0) {
            clamped_new_x = 0;
        } else if (clamped_new_x > map_width_f) {
            clamped_new_x = map_width_f;
        }
        if (clamped_new_y < 0) {
            clamped_new_y = 0;
        } else if (clamped_new_y > map_height_f) {
            clamped_new_y = map_height_f;
        }
        // Get terrain at the new position and check movement probability
        const target_terrain = map.getTerrainAt(@intFromFloat(clamped_new_x), @intFromFloat(clamped_new_y));
        const target_effects = TerrainEffect.forAgentAndTerrain(agent.type, target_terrain);
        
        break :blk @mod(agent.seed, 100) < target_effects.movement_prob;
    };
    
    // Always consume energy on movement attempt, even if move is blocked
    var attempted_move = false;
    if (can_move) {
        attempted_move = true;
    } else if (agent.vx != 0 or agent.vy != 0) {
        attempted_move = true;
    }
    if (attempted_move) {
        // Use terrain at current or attempted position for cost
        const cost_terrain = map.getTerrainAt(@intFromFloat(agent.x), @intFromFloat(agent.y));
        const cost_effects = TerrainEffect.forAgentAndTerrain(agent.type, cost_terrain);
        const energy_cost = agent.calculateEnergyCost(
            agent.vx, agent.vy, 
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
