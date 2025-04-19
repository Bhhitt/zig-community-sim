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

// States that an interaction can be in
pub const InteractionState = enum {
    Initiating, // Agents are moving toward each other
    Active,     // Agents are actively interacting
    Concluding, // Interaction is ending
    Finishing   // Final stage of interaction (legacy name for compatibility)
};

pub const Interaction = struct {
    agent1_id: usize,
    agent2_id: usize,
    type: InteractionType,
    duration: u8, // How many more simulation ticks this interaction will last
    state: InteractionState, // Current phase of the interaction
    
    pub fn init(agent1: Agent, agent2: Agent, interaction_type: InteractionType) Interaction {
        // Calculate if agents are already adjacent
        const dx = if (agent1.x > agent2.x) agent1.x - agent2.x else agent2.x - agent1.x;
        const dy = if (agent1.y > agent2.y) agent1.y - agent2.y else agent2.y - agent1.y;
        const manhattan_dist = dx + dy;
        
        // If already adjacent, start in Active state, otherwise in Initiating
        const initial_state: InteractionState = if (manhattan_dist <= 1.0) 
                                              InteractionState.Active 
                                              else 
                                              InteractionState.Initiating;
        return .{
            .agent1_id = agent1.id,
            .agent2_id = agent2.id,
            .type = interaction_type,
            .duration = 10, // Default duration
            .state = initial_state,
        };
    }
    
    pub fn toString(self: Interaction) []const u8 {
        // Returns a string representation of the interaction
        // Format: "Agent1 <-> Agent2 (Type, State, Duration left)"
        // Note: This is a simplified version. For more details, adjust as needed.
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{d} <-> {d} ({s}, {s}, {d} ticks left)",
            .{ self.agent1_id, self.agent2_id, @tagName(self.type), @tagName(self.state), self.duration }
        ) catch "<interaction>";
    }
};

const TerrainEffectData = @import("terrain_effects").TerrainEffectData;

// Represents how terrain affects different agent types
pub const TerrainEffect = struct {
    // Default/neutral effects
    const DEFAULT_EFFECT = TerrainEffectData{
        .movement_cost = 0,
        .movement_prob = 100,
        .energy_gain = 0,
        .health_effect = 0,
    };
    
    // (Legacy terrain effect arrays removed; use terrain_effects.zig for all terrain logic)
    
    // Get terrain effects based on agent type and terrain
    pub fn forAgentAndTerrain(agent_type: AgentType, terrain: Terrain) TerrainEffectData {
        // Use the canonical terrain effect logic from terrain_effects.zig
        return @import("terrain_effects").TerrainEffect.forAgentAndTerrain(agent_type, terrain);
    }
};

// Movement result type to encapsulate direction calculation
const MovementResult = struct {
    dx: f32 = 0,
    dy: f32 = 0,
    
    fn applyDoubleStep(self: *MovementResult, double_step_chance: u8, random_value: u64) void {
        if (double_step_chance > 0 and @mod(random_value, 100) < double_step_chance) {
            self.dx *= 2.0;
            self.dy *= 2.0;
        }
    }
};

pub const Agent = struct {
    id: usize,
    x: f32,
    y: f32,
    type: AgentType,
    health: u8,
    energy: u8,
    hunger: u8, // 0 = not hungry, higher = hungrier
    seed: u64, // Unique seed for agent's random movements
    speed: f32 = 0.4, // cells per tick (reduced for smoother movement)
    vx: f32 = 0.0,
    vy: f32 = 0.0,
    smoothness: f32 = 0.0, // 0 = instant turn, 1 = very smooth/slow turn
    
    // Perception fields
    nearest_food_x: ?f32 = null,
    nearest_food_y: ?f32 = null,
    nearest_food_dist: ?f32 = null,
    nearby_agent_count: usize = 0,
    
    // Interaction tracking
    last_interaction_partner: ?usize = null,
    interaction_target_id: ?usize = null,
    
    // Agent configuration
    const max_health = 100;
    const max_energy = 100;
    const health_regen = 1; // Default health regeneration
    
    pub fn init(id: usize, x: f32, y: f32, agent_type: AgentType, health: u8, energy: u8) Agent {
        // Use smoothness from agent type's movement pattern
        const smoothness = agent_type.getMovementPattern().smoothness;
        return .{
            .id = id,
            .x = x,
            .y = y,
            .type = agent_type,
            .health = health,
            .energy = energy,
            .hunger = 0,
            .seed = std.crypto.random.int(u64),
            .speed = 0.4,
            .vx = 0.0,
            .vy = 0.0,
            .smoothness = smoothness,
            .nearest_food_x = null,
            .nearest_food_y = null,
            .nearest_food_dist = null,
            .nearby_agent_count = 0,
            .last_interaction_partner = null,
            .interaction_target_id = null,
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
    pub fn calculateMovement(self: *Agent, pattern: MovementPattern, config: anytype) MovementResult {
        const random_value = self.updateSeed();
        var result = MovementResult{};
        
        // Configurable hunger-driven food seeking
        if (self.hunger > 50 and self.nearest_food_x != null and self.nearest_food_y != null) {
            // Calculate aggressiveness as a function of hunger and config
            const base = config.food_seek_aggressiveness_base;
            const coeff = config.food_seek_aggressiveness_hunger_coeff;
            const hunger_f32: f32 = @floatFromInt(self.hunger);
            const prob = base + coeff * hunger_f32;
            const rand_mod: u32 = @truncate(random_value % 1000);
            const rand_f32: f32 = @floatFromInt(rand_mod);
            if ((rand_f32 / 1000.0) < prob) {
                // SAFETY: Both nearest_food_x and nearest_food_y are checked for null above, so safe to unwrap
                const nfx = self.nearest_food_x.?;
                const nfy = self.nearest_food_y.?;
                const dx = nfx - self.x;
                const dy = nfy - self.y;
                result.dx = if (dx > 0.1) 1.0 else if (dx < -0.1) -1.0 else 0.0;
                result.dy = if (dy > 0.1) 1.0 else if (dy < -0.1) -1.0 else 0.0;
                return result;
            }
        }
        
        // Check if agent should move this turn
        if (@mod(random_value, 100) >= pattern.move_chance) {
            return result; // No movement
        }
        
        // Pattern-based movement (used by Builder)
        if (pattern.pattern_based) {
            const pattern_val = @mod(random_value, 8);
            const x_int = @as(i32, @intFromFloat(self.x));
            const y_int = @as(i32, @intFromFloat(self.y));
            if (pattern_val < 2) {
                // Move in small square pattern
                if (@mod(x_int + y_int, 2) == 0) {
                    result.dx = 1.0;
                } else {
                    result.dy = 1.0;
                }
            } else if (pattern_val < 4) {
                // Move in another pattern
                if (@mod(x_int + y_int, 2) == 0) {
                    result.dx = -1.0;
                } else {
                    result.dy = -1.0;
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
                0 => result.dx = 1.0,  // East
                1 => { result.dx = 1.0; result.dy = 1.0; },  // Southeast
                2 => result.dy = 1.0,  // South
                3 => { result.dx = -1.0; result.dy = 1.0; },  // Southwest
                4 => result.dx = -1.0,  // West
                5 => { result.dx = -1.0; result.dy = -1.0; },  // Northwest
                6 => result.dy = -1.0,  // North
                7 => { result.dx = 1.0; result.dy = -1.0; },  // Northeast
                else => {}, // Unreachable
            }
            
            result.applyDoubleStep(pattern.double_step_chance, random_value);
            return result;
        }
        
        // Home-seeking behavior (used by Farmer)
        if (pattern.home_seeking and @mod(random_value, 100) < pattern.home_seeking_chance) {
            // Determine "home" based on ID
            const center_x = @mod(self.id * 7, 10);
            const center_x_f32: f32 = @floatFromInt(center_x);
            const center_y = @mod(self.id * 13, 10);
            const center_y_f32: f32 = @floatFromInt(center_y);
            
            if (self.x > center_x_f32 and @mod(random_value, 2) == 0) {
                result.dx = -1.0;
            } else if (self.x < center_x_f32 and @mod(random_value, 2) == 0) {
                result.dx = 1.0;
            }
            
            if (self.y > center_y_f32 and @mod(random_value, 2) == 0) {
                result.dy = -1.0;
            } else if (self.y < center_y_f32 and @mod(random_value, 2) == 0) {
                result.dy = 1.0;
            }
            
            return result;
        }
        
        // Standard directional movement
        const direction_val = @mod(random_value, 100);
        var direction_sum: u8 = 0;
        
        // Apply directional bias
        direction_sum += pattern.directional_bias.north;
        if (direction_val < direction_sum) {
            result.dy = -1.0;
        } else {
            direction_sum += pattern.directional_bias.south;
            if (direction_val < direction_sum) {
                result.dy = 1.0;
            } else {
                direction_sum += pattern.directional_bias.east;
                if (direction_val < direction_sum) {
                    result.dx = 1.0;
                } else {
                    result.dx = -1.0; // Default to west
                }
            }
        }
        
        // Convert to diagonal if needed
        if (pattern.can_move_diagonally and @mod(random_value, 100) < pattern.diagonal_chance) {
            if (result.dx == 0) {
                result.dx = if (@mod(random_value, 2) == 0) -1.0 else 1.0;
            } else if (result.dy == 0) {
                result.dy = if (@mod(random_value, 2) == 0) -1.0 else 1.0;
            }
        }
        
        // Apply double step if needed
        result.applyDoubleStep(pattern.double_step_chance, random_value);
        
        return result;
    }
    
    // Calculate new position with boundary checks
    pub fn calculateNewPosition(self: Agent, dx: f32, dy: f32) struct { x: f32, y: f32 } {
        var new_x = self.x;
        var new_y = self.y;
        
        // Handle x-direction movement with boundary checks
        if (dx < 0) {
            const abs_dx: f32 = @abs(dx);
            if (new_x >= abs_dx) {
                new_x -= abs_dx;
            } else {
                new_x = 0;
            }
        } else if (dx > 0) {
            new_x += dx;
        }
        
        // Handle y-direction movement with boundary checks
        if (dy < 0) {
            const abs_dy: f32 = @abs(dy);
            if (new_y >= abs_dy) {
                new_y -= abs_dy;
            } else {
                new_y = 0;
            }
        } else if (dy > 0) {
            new_y += dy;
        }
        
        return .{ .x = new_x, .y = new_y };
    }
    
    // Calculate energy cost for movement
    pub fn calculateEnergyCost(_: Agent, dx: f32, dy: f32, base_cost: u8, terrain_cost: u8) u8 {
        // If not moving, no energy cost
        if (dx == 0 and dy == 0) return 0;
        
        // Calculate distance factor
        const distance_factor: f32 = @max(@abs(dx), @abs(dy));
        var result = base_cost * @as(u8, @intFromFloat(distance_factor));
        result += terrain_cost;
        // Always consume at least 1 energy for any movement attempt
        result = @max(result, 1);
        // Cap at 20 to prevent excessive energy drain
        return @min(result, 20);
    }
    
    // Apply health effects from terrain
    pub fn applyHealthEffects(self: *Agent, health_effect: i8) void {
        const health_effect_i8 = if (health_effect < 0) 0 else health_effect;
        const health_effect_u8: u8 = @intCast(health_effect_i8);
        if (health_effect_u8 > 0) {
            // Health boost
            self.health = @min(self.health + health_effect_u8, max_health);
        } else {
            // Health penalty
            const health_penalty = @abs(health_effect);
            const penalty: u8 = if (health_penalty > 255) 255 else @as(u8, health_penalty);
            if (self.health > penalty) {
                self.health -= penalty;
            } else {
                self.health = 1; // Don't let health drop to 0 automatically
            }
        }
    }
};