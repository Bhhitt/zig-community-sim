const std = @import("std");
const Terrain = @import("../world/terrain.zig").Terrain;
const AgentType = @import("agent_type.zig").AgentType;

// Data structure for terrain effects
pub const TerrainEffectData = struct {
    movement_cost: u8, // Additional energy cost for this terrain
    movement_prob: u8, // Probability of successful movement (out of 100)
    energy_gain: u8,   // Energy gained from being on this terrain (per update)
    health_effect: i8, // Health effect from being on this terrain (per update, can be negative)
};

// Represents how terrain affects different agent types
pub const TerrainEffect = struct {
    // Helper function to get terrain effect data
    fn getData(agent_type: AgentType, terrain: Terrain) TerrainEffectData {
        // Define terrain effect data tables for each agent type
        // These could be moved to a data file/constant in a larger system
        const terrain_effects = [6][5]TerrainEffectData{
            // Settler effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 1, .health_effect = 1 },  // Grass
                .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 },   // Forest
                .{ .movement_cost = 3, .movement_prob = 30, .energy_gain = 0, .health_effect = -1 },  // Mountain
                .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -2 },  // Water
            },
            // Explorer effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Grass
                .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 },   // Forest
                .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },   // Mountain
                .{ .movement_cost = 3, .movement_prob = 40, .energy_gain = 0, .health_effect = -1 },  // Water
            },
            // Builder effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Grass
                .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },   // Forest
                .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },  // Mountain
                .{ .movement_cost = 6, .movement_prob = 10, .energy_gain = 0, .health_effect = -2 },  // Water
            },
            // Farmer effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 2, .health_effect = 1 },  // Grass
                .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 1, .health_effect = 0 },   // Forest
                .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },  // Mountain
                .{ .movement_cost = 4, .movement_prob = 30, .energy_gain = 1, .health_effect = 0 },   // Water
            },
            // Miner effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Grass
                .{ .movement_cost = 2, .movement_prob = 60, .energy_gain = 0, .health_effect = 0 },   // Forest
                .{ .movement_cost = 1, .movement_prob = 90, .energy_gain = 2, .health_effect = 0 },   // Mountain
                .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },  // Water
            },
            // Scout effects
            [5]TerrainEffectData{
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Empty
                .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },  // Grass
                .{ .movement_cost = 0, .movement_prob = 90, .energy_gain = 0, .health_effect = 0 },   // Forest
                .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },   // Mountain
                .{ .movement_cost = 3, .movement_prob = 50, .energy_gain = 0, .health_effect = -1 },  // Water
            },
        };
        
        const agent_idx = @intFromEnum(agent_type);
        const terrain_idx = @intFromEnum(terrain);
        
        return terrain_effects[agent_idx][terrain_idx];
    }
    
    // Get terrain effects based on agent type and terrain
    pub fn forAgentAndTerrain(agent_type: AgentType, terrain: Terrain) TerrainEffectData {
        return getData(agent_type, terrain);
    }
};

// Calculate energy cost for movement
pub fn calculateEnergyCost(
    base_cost: u8, 
    moved: bool, 
    dx: i8, 
    dy: i8, 
    terrain_cost: u8
) u8 {
    if (!moved) return 0;
    
    // Apply distance factor (max of dx, dy)
    const distance_factor = @max(@abs(dx), @abs(dy));
    var cost = base_cost * @as(u8, @intCast(distance_factor));
    
    // Add terrain movement cost
    cost += terrain_cost;
    
    // Cap at 20 to prevent excessive energy drain
    return @min(cost, 20);
}

// Apply terrain health effects to health value
pub fn applyHealthEffects(health: u8, health_effect: i8, max_health: u8, health_regen: u8) u8 {
    var new_health = health;
    
    if (health_effect > 0) {
        // Positive health effect (healing)
        new_health = @min(new_health + @as(u8, @intCast(health_effect)), max_health);
    } else if (health_effect < 0) {
        // Negative health effect (damage)
        const health_penalty = @abs(health_effect);
        if (new_health > health_penalty) {
            new_health -= @intCast(health_penalty);
        } else {
            new_health = 1; // Don't let health drop to 0 automatically
        }
    } else {
        // No health effect - apply natural regeneration
        if (new_health < max_health) {
            new_health = @min(new_health + health_regen, max_health);
        }
    }
    
    return new_health;
}

// Apply terrain energy effects to energy value
pub fn applyEnergyEffects(energy: u8, energy_gain: u8, max_energy: u8) u8 {
    if (energy_gain > 0) {
        return @min(energy + energy_gain, max_energy);
    }
    return energy;
}