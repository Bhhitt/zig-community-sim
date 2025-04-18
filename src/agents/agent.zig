const std = @import("std");
const random = std.crypto.random;
const hash = std.hash;
const map_mod = @import("map");
const Terrain = map_mod.Terrain;
const Map = map_mod.Map;
pub const AgentType = @import("agent_type").AgentType;
const movement_types = @import("movement_types");
const MovementTendency = movement_types.MovementTendency;
const MovementPattern = movement_types.MovementPattern;
pub const InteractionType = @import("interaction_type").InteractionType;

pub const Interaction = struct {
    agent1_id: usize,
    agent2_id: usize,
    type: InteractionType,
    duration: u8, // How many more simulation ticks this interaction will last
    
    pub fn init(agent1: Agent, agent2: Agent, interaction_type: InteractionType) Interaction {
        return .{
            .agent1_id = agent1.id,
            .agent2_id = agent2.id,
            .type = interaction_type,
            .duration = 3, // Default duration
        };
    }
    
    pub fn toString(self: Interaction) []const u8 {
        // Returns a string representation of the interaction
        // Format: "Agent1 <-> Agent2 (Type, Duration left)"
        // Note: This is a simplified version. For more details, adjust as needed.
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{d} <-> {d} ({s}, {d} ticks left)",
            .{ self.agent1_id, self.agent2_id, @tagName(self.type), self.duration }
        ) catch "<interaction>";
    }
};

// TerrainEffectData stores the actual effect values
pub const TerrainEffectData = struct {
    movement_cost: u8, // Additional energy cost for this terrain
    movement_prob: u8, // Probability of successful movement (out of 100)
    energy_gain: u8,   // Energy gained from being on this terrain (per update)
    health_effect: i8, // Health effect from being on this terrain (per update)
};

// Represents how terrain affects different agent types
pub const TerrainEffect = struct {
    // Default/neutral effects
    const DEFAULT_EFFECT = TerrainEffectData{
        .movement_cost = 0,
        .movement_prob = 100,
        .energy_gain = 0,
        .health_effect = 0,
    };
    
    // Terrain effect constants for each agent type and terrain
    const TERRAIN_EFFECTS = struct {
        const SETTLER = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 1, .health_effect = 1 },  // Settlers like grasslands
            .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 },
            .{ .movement_cost = 3, .movement_prob = 30, .energy_gain = 0, .health_effect = -1 },
            .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -2 },
        };
        
        const EXPLORER = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            DEFAULT_EFFECT,
            .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 },
            .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 }, // Explorers handle mountains better
            .{ .movement_cost = 3, .movement_prob = 40, .energy_gain = 0, .health_effect = -1 }, // Explorers are better at crossing water
        };
        
        const BUILDER = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            DEFAULT_EFFECT,
            .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },
            .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
            .{ .movement_cost = 6, .movement_prob = 10, .energy_gain = 0, .health_effect = -2 }, // Builders struggle in water
        };
        
        const FARMER = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 2, .health_effect = 1 }, // Farmers thrive on grassland
            .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 1, .health_effect = 0 },
            .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
            .{ .movement_cost = 4, .movement_prob = 30, .energy_gain = 1, .health_effect = 0 }, // Farmers can use water
        };
        
        const MINER = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            DEFAULT_EFFECT,
            .{ .movement_cost = 2, .movement_prob = 60, .energy_gain = 0, .health_effect = 0 },
            .{ .movement_cost = 1, .movement_prob = 90, .energy_gain = 2, .health_effect = 0 }, // Miners thrive in mountains
            .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
        };
        
        const SCOUT = [5]TerrainEffectData{
            // Empty, Grass, Forest, Mountain, Water
            DEFAULT_EFFECT,
            DEFAULT_EFFECT,
            .{ .movement_cost = 0, .movement_prob = 90, .energy_gain = 0, .health_effect = 0 }, // Scouts are good in forests
            .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },
            .{ .movement_cost = 3, .movement_prob = 50, .energy_gain = 0, .health_effect = -1 },
        };
    };
    
    // Get terrain effects based on agent type and terrain
    pub fn forAgentAndTerrain(agent_type: AgentType, terrain: Terrain) TerrainEffectData {
        const terrain_idx = @intFromEnum(terrain);
        return switch (agent_type) {
            .Settler => TERRAIN_EFFECTS.SETTLER[terrain_idx],
            .Explorer => TERRAIN_EFFECTS.EXPLORER[terrain_idx],
            .Builder => TERRAIN_EFFECTS.BUILDER[terrain_idx],
            .Farmer => TERRAIN_EFFECTS.FARMER[terrain_idx],
            .Miner => TERRAIN_EFFECTS.MINER[terrain_idx],
            .Scout => TERRAIN_EFFECTS.SCOUT[terrain_idx],
        };
    }
};

// Movement result type to encapsulate direction calculation
const MovementResult = struct {
    dx: i8 = 0,
    dy: i8 = 0,
    
    fn applyDoubleStep(self: *MovementResult, double_step_chance: u8, random_value: u64) void {
        if (double_step_chance > 0 and @mod(random_value, 100) < double_step_chance) {
            self.dx *= 2;
            self.dy *= 2;
        }
    }
};

pub const Agent = struct {
    id: usize,
    x: usize,
    y: usize,
    type: AgentType,
    health: u8,
    energy: u8,
    seed: u64, // Unique seed for agent's random movements
    
    // Agent configuration
    const max_health = 100;
    const max_energy = 100;
    const health_regen = 1; // Default health regeneration
    
    pub fn init(id: usize, x: usize, y: usize, agent_type: AgentType, health: u8, energy: u8) Agent {
        return .{
            .id = id,
            .x = x,
            .y = y,
            .type = agent_type,
            .health = health,
            .energy = energy,
            .seed = std.crypto.random.int(u64), // Initialize with random seed
        };
    }
    
    pub fn getSymbol(self: Agent) u8 {
        return self.type.getSymbol();
    }
    
    // Update the agent's random seed
    fn updateSeed(self: *Agent) u64 {
        const timestamp = @as(u64, @bitCast(@abs(std.time.milliTimestamp())));
        self.seed = (self.seed +% timestamp) *% 6364136223846793005 +% self.id;
        return self.seed;
    }
    
    // Calculate movement direction based on agent type and pattern
    pub fn calculateMovement(self: *Agent, pattern: MovementPattern) MovementResult {
        const random_value = self.updateSeed();
        var result = MovementResult{};
        
        // Check if agent should move this turn
        if (@mod(random_value, 100) >= pattern.move_chance) {
            return result; // No movement
        }
        
        // Pattern-based movement (used by Builder)
        if (pattern.pattern_based) {
            const pattern_val = @mod(random_value, 8);
            
            if (pattern_val < 2) {
                // Move in small square pattern
                if (@mod(self.x + self.y, 2) == 0) {
                    result.dx = 1;
                } else {
                    result.dy = 1;
                }
            } else if (pattern_val < 4) {
                // Move in another pattern
                if (@mod(self.x + self.y, 2) == 0) {
                    result.dx = -1;
                } else {
                    result.dy = -1;
                }
            }
            return result;
        }
        
        // Spiral movement (used by Scout)
        if (pattern.spiral_movement) {
            const timestamp = @as(u64, @bitCast(@abs(std.time.milliTimestamp())));
            const time_component = @as(u8, @truncate(@mod(timestamp, 4)));
            const direction = @mod(random_value + time_component, 8);
            
            switch (direction) {
                0 => result.dx = 1,  // East
                1 => { result.dx = 1; result.dy = 1; },  // Southeast
                2 => result.dy = 1,  // South
                3 => { result.dx = -1; result.dy = 1; },  // Southwest
                4 => result.dx = -1,  // West
                5 => { result.dx = -1; result.dy = -1; },  // Northwest
                6 => result.dy = -1,  // North
                7 => { result.dx = 1; result.dy = -1; },  // Northeast
                else => {}, // Unreachable
            }
            
            result.applyDoubleStep(pattern.double_step_chance, random_value);
            return result;
        }
        
        // Home-seeking behavior (used by Farmer)
        if (pattern.home_seeking and @mod(random_value, 100) < pattern.home_seeking_chance) {
            // Determine "home" based on ID
            const center_x = @mod(self.id * 7, 10);
            const center_y = @mod(self.id * 13, 10);
            
            if (self.x > center_x and @mod(random_value, 2) == 0) {
                result.dx = -1;
            } else if (self.x < center_x and @mod(random_value, 2) == 0) {
                result.dx = 1;
            }
            
            if (self.y > center_y and @mod(random_value, 2) == 0) {
                result.dy = -1;
            } else if (self.y < center_y and @mod(random_value, 2) == 0) {
                result.dy = 1;
            }
            
            return result;
        }
        
        // Standard directional movement
        const direction_val = @mod(random_value, 100);
        var direction_sum: u8 = 0;
        
        // Apply directional bias
        direction_sum += pattern.directional_bias.north;
        if (direction_val < direction_sum) {
            result.dy = -1;
        } else {
            direction_sum += pattern.directional_bias.south;
            if (direction_val < direction_sum) {
                result.dy = 1;
            } else {
                direction_sum += pattern.directional_bias.east;
                if (direction_val < direction_sum) {
                    result.dx = 1;
                } else {
                    result.dx = -1; // Default to west
                }
            }
        }
        
        // Convert to diagonal if needed
        if (pattern.can_move_diagonally and @mod(random_value, 100) < pattern.diagonal_chance) {
            if (result.dx == 0) {
                result.dx = if (@mod(random_value, 2) == 0) -1 else 1;
            } else if (result.dy == 0) {
                result.dy = if (@mod(random_value, 2) == 0) -1 else 1;
            }
        }
        
        // Apply double step if needed
        result.applyDoubleStep(pattern.double_step_chance, random_value);
        
        return result;
    }
    
    // Calculate new position with boundary checks
    pub fn calculateNewPosition(self: Agent, dx: i8, dy: i8) struct { x: usize, y: usize } {
        var new_x = self.x;
        var new_y = self.y;
        
        // Handle x-direction movement with boundary checks
        if (dx < 0) {
            const abs_dx = @abs(dx);
            if (new_x >= abs_dx) {
                new_x -= @as(u8, @intCast(abs_dx));
            } else {
                new_x = 0;
            }
        } else if (dx > 0) {
            new_x += @as(u8, @intCast(dx));
        }
        
        // Handle y-direction movement with boundary checks
        if (dy < 0) {
            const abs_dy = @abs(dy);
            if (new_y >= abs_dy) {
                new_y -= @as(u8, @intCast(abs_dy));
            } else {
                new_y = 0;
            }
        } else if (dy > 0) {
            new_y += @as(u8, @intCast(dy));
        }
        
        return .{ .x = new_x, .y = new_y };
    }
    
    // Calculate energy cost for movement
    pub fn calculateEnergyCost(_: Agent, dx: i8, dy: i8, base_cost: u8, terrain_cost: u8) u8 {
        // If not moving, no energy cost
        if (dx == 0 and dy == 0) return 0;
        
        // Calculate distance factor
        const distance_factor = @max(@abs(dx), @abs(dy));
        var result = base_cost * @as(u8, @intCast(distance_factor));
        
        // Add terrain movement cost
        result += terrain_cost;
        
        // Cap at 20 to prevent excessive energy drain
        return @min(result, 20);
    }
    
    // Apply health effects from terrain
    pub fn applyHealthEffects(self: *Agent, health_effect: i8) void {
        if (health_effect > 0) {
            // Health boost
            self.health = @min(self.health + @as(u8, @intCast(health_effect)), max_health);
        } else if (health_effect < 0) {
            // Health penalty
            const health_penalty = @abs(health_effect);
            if (self.health > health_penalty) {
                self.health -= @as(u8, @intCast(health_penalty));
            } else {
                self.health = 1; // Don't let health drop to 0 automatically
            }
        } else {
            // Natural health regeneration when no terrain effect
            if (self.health < max_health) {
                self.health = @min(self.health + health_regen, max_health);
            }
        }
    }
};