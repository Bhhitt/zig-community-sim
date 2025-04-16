const std = @import("std");
const random = std.crypto.random;
const hash = std.hash;
const Terrain = @import("map.zig").Terrain;

pub const AgentType = enum {
    Settler,
    Explorer,
    Builder,
    Farmer,
    Miner,
    Scout,
};

pub const InteractionType = enum {
    Greeting,
    Trading,
    Collaboration,
    Teaching,
    Resource,
    
    pub fn getSymbol(self: InteractionType) u8 {
        return switch (self) {
            .Greeting => 'G',
            .Trading => 'T',
            .Collaboration => 'C',
            .Teaching => 'E',  // Education
            .Resource => 'R',
        };
    }
};

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
};

// Represents how terrain affects different agent types
pub const TerrainEffect = struct {
    movement_cost: u8, // Additional energy cost for this terrain
    movement_prob: u8, // Probability of successful movement (out of 100)
    energy_gain: u8,   // Energy gained from being on this terrain (per update)
    health_effect: i8, // Health effect from being on this terrain (per update, can be negative)
    
    // Get terrain effects based on agent type and terrain
    pub fn forAgentAndTerrain(agent_type: AgentType, terrain: Terrain) TerrainEffect {
        switch (agent_type) {
            .Settler => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 1, .health_effect = 1 },  // Settlers like grasslands
                    .Forest => .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 },
                    .Mountain => .{ .movement_cost = 3, .movement_prob = 30, .energy_gain = 0, .health_effect = -1 },
                    .Water => .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -2 },
                };
            },
            .Explorer => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Forest => .{ .movement_cost = 1, .movement_prob = 80, .energy_gain = 0, .health_effect = 0 }, 
                    .Mountain => .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 }, // Explorers handle mountains better
                    .Water => .{ .movement_cost = 3, .movement_prob = 40, .energy_gain = 0, .health_effect = -1 },  // Explorers are better at crossing water
                };
            },
            .Builder => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Forest => .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },
                    .Mountain => .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
                    .Water => .{ .movement_cost = 6, .movement_prob = 10, .energy_gain = 0, .health_effect = -2 }, // Builders struggle in water
                };
            },
            .Farmer => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 2, .health_effect = 1 }, // Farmers thrive on grassland
                    .Forest => .{ .movement_cost = 1, .movement_prob = 70, .energy_gain = 1, .health_effect = 0 },
                    .Mountain => .{ .movement_cost = 4, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
                    .Water => .{ .movement_cost = 4, .movement_prob = 30, .energy_gain = 1, .health_effect = 0 }, // Farmers can use water
                };
            },
            .Miner => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Forest => .{ .movement_cost = 2, .movement_prob = 60, .energy_gain = 0, .health_effect = 0 },
                    .Mountain => .{ .movement_cost = 1, .movement_prob = 90, .energy_gain = 2, .health_effect = 0 }, // Miners thrive in mountains
                    .Water => .{ .movement_cost = 5, .movement_prob = 20, .energy_gain = 0, .health_effect = -1 },
                };
            },
            .Scout => {
                return switch (terrain) {
                    .Empty => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Grass => .{ .movement_cost = 0, .movement_prob = 100, .energy_gain = 0, .health_effect = 0 },
                    .Forest => .{ .movement_cost = 0, .movement_prob = 90, .energy_gain = 0, .health_effect = 0 }, // Scouts are good in forests
                    .Mountain => .{ .movement_cost = 2, .movement_prob = 70, .energy_gain = 0, .health_effect = 0 },
                    .Water => .{ .movement_cost = 3, .movement_prob = 50, .energy_gain = 0, .health_effect = -1 },
                };
            },
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
        return switch (self.type) {
            .Settler => 'S',
            .Explorer => 'E',
            .Builder => 'B',
            .Farmer => 'F',
            .Miner => 'M',
            .Scout => 'C',  // Scout uses 'C' for cartographer
        };
    }
    
    pub fn update(self: *Agent, map: *const @import("map.zig").Map) void {
        // Different movement patterns based on agent type
        var dx: i8 = 0;
        var dy: i8 = 0;
        
        // Mix timestamp with agent's unique seed for random movement
        const timestamp = @as(u64, @bitCast(std.time.milliTimestamp()));
        // Create a simple random number by mixing the seed with timestamp and ID
        self.seed = (self.seed +% timestamp) *% 6364136223846793005 +% self.id;
        const random_value = self.seed;
        
        switch (self.type) {
            .Settler => {
                // Settlers move slowly and methodically, preferring to stay in place
                // They occasionally move to adjacent cells, but rarely
                const should_move = @mod(random_value, 10) < 3; // 30% chance to move
                
                if (should_move) {
                    const dir = @mod(random_value, 4);
                    switch (dir) {
                        0 => dx = -1,
                        1 => dx = 1,
                        2 => dy = -1,
                        3 => dy = 1,
                        else => {}, // Unreachable
                    }
                }
            },
            .Explorer => {
                // Explorers move quickly and in straight lines
                // They continue in same direction for multiple steps, then change
                const pattern = @mod(random_value, 12);
                
                if (pattern < 4) {
                    // Move east
                    dx = 1;
                } else if (pattern < 8) {
                    // Move west
                    dx = -1;
                } else if (pattern < 10) {
                    // Move north
                    dy = -1;
                } else {
                    // Move south
                    dy = 1;
                }
                
                // Occasionally move farther (double step)
                if (@mod(random_value, 7) == 0) {
                    dx *= 2;
                    dy *= 2;
                }
            },
            .Builder => {
                // Builders move in patterns, creating small clusters
                // They tend to move in small squares or rectangles
                const pattern = @mod(random_value, 8);
                
                if (pattern < 2) {
                    // Move in small square pattern
                    if (@mod(self.x + self.y, 2) == 0) {
                        dx = 1;
                    } else {
                        dy = 1;
                    }
                } else if (pattern < 4) {
                    // Move in another pattern
                    if (@mod(self.x + self.y, 2) == 0) {
                        dx = -1;
                    } else {
                        dy = -1;
                    }
                } else {
                    // Sometimes stay put, focusing on "building"
                    // No movement
                }
            },
            .Farmer => {
                // Farmers move in small, confined areas, simulating tending fields
                // They rarely venture far from their starting position
                
                // Move within a small radius, with higher probability to stay put
                const should_move = @mod(random_value, 10) < 4; // 40% chance to move
                
                if (should_move) {
                    // Usually only move 1 cell at a time
                    const dir = @mod(random_value, 4);
                    switch (dir) {
                        0 => dx = -1,
                        1 => dx = 1,
                        2 => dy = -1,
                        3 => dy = 1,
                        else => {}, // Unreachable
                    }
                }
                
                // Occasionally return toward the center (based on their ID as a rudimentary "home")
                if (@mod(random_value, 20) == 0) {
                    // Pull toward a location determined by their ID
                    const center_x = @mod(self.id * 7, 10); // Spread farmers out
                    const center_y = @mod(self.id * 13, 10);
                    
                    if (self.x > center_x and @mod(random_value, 2) == 0) {
                        dx = -1;
                    } else if (self.x < center_x and @mod(random_value, 2) == 0) {
                        dx = 1;
                    }
                    
                    if (self.y > center_y and @mod(random_value, 2) == 0) {
                        dy = -1;
                    } else if (self.y < center_y and @mod(random_value, 2) == 0) {
                        dy = 1;
                    }
                }
            },
            .Miner => {
                // Miners tend to go directly toward mountainous areas
                // They move deliberately but slower than explorers
                
                // Basic movement pattern
                const pattern = @mod(random_value, 10);
                
                if (pattern < 2) {
                    dx = -1;
                } else if (pattern < 4) {
                    dx = 1;
                } else if (pattern < 6) {
                    dy = -1;
                } else if (pattern < 8) {
                    dy = 1;
                } else {
                    // Stay in place occasionally, "mining"
                }
                
                // Miners sometimes make diagonal moves
                if (@mod(random_value, 15) == 0) {
                    if (dx != 0 or dy != 0) {
                        // Make the move diagonal
                        if (dx == 0) dx = if (@mod(random_value, 2) == 0) -1 else 1;
                        if (dy == 0) dy = if (@mod(random_value, 2) == 0) -1 else 1;
                    }
                }
            },
            .Scout => {
                // Scouts move in a spiral-like pattern, exploring terrain
                // They prioritize covering new ground
                
                // Favor a direction that changes frequently
                const time_component = @as(u8, @truncate(@mod(timestamp, 4)));
                const direction = @mod(random_value + time_component, 8);
                
                switch (direction) {
                    0 => dx = 1,  // East
                    1 => { dx = 1; dy = 1; },  // Southeast
                    2 => dy = 1,  // South
                    3 => { dx = -1; dy = 1; },  // Southwest
                    4 => dx = -1,  // West
                    5 => { dx = -1; dy = -1; },  // Northwest
                    6 => dy = -1,  // North
                    7 => { dx = 1; dy = -1; },  // Northeast
                    else => {}, // Unreachable
                }
                
                // Scouts occasionally make larger jumps to explore new areas
                if (@mod(random_value, 25) == 0) {
                    dx *= 2;
                    dy *= 2;
                }
            },
        }
        
        // Get current terrain the agent is on
        const current_terrain = map.getTerrainAt(self.x, self.y);
        const terrain_effects = TerrainEffect.forAgentAndTerrain(self.type, current_terrain);
        
        // Apply terrain effects
        if (terrain_effects.energy_gain > 0) {
            const new_energy = @min(self.energy + terrain_effects.energy_gain, max_energy);
            self.energy = new_energy;
        }
        
        if (terrain_effects.health_effect != 0) {
            if (terrain_effects.health_effect > 0) {
                const new_health = @min(self.health + @as(u8, @intCast(terrain_effects.health_effect)), max_health);
                self.health = new_health;
            } else {
                // Health penalty
                const health_penalty = @abs(terrain_effects.health_effect);
                if (self.health > health_penalty) {
                    self.health -= @intCast(health_penalty);
                } else {
                    self.health = 1; // Don't let health drop to 0 automatically
                }
            }
        } else {
            // Natural health regeneration when no terrain effect
            if (self.health < max_health) {
                self.health = @min(self.health + health_regen, max_health);
            }
        }
        
        // Check if agent can move based on terrain
        const move_allowed = blk: {
            // No movement planned
            if (dx == 0 and dy == 0) break :blk true;
            
            // Get the new position
            var new_x = self.x;
            var new_y = self.y;
            
            // Calculate new position with boundary checks
            if (dx < 0) {
                const abs_dx = @abs(dx);
                if (self.x >= abs_dx) {
                    new_x -= @intCast(abs_dx);
                } else {
                    new_x = 0;
                }
            } else if (dx > 0) {
                new_x += @intCast(dx);
            }
            
            if (dy < 0) {
                const abs_dy = @abs(dy);
                if (self.y >= abs_dy) {
                    new_y -= @intCast(abs_dy);
                } else {
                    new_y = 0;
                }
            } else if (dy > 0) {
                new_y += @intCast(dy);
            }
            
            // Get terrain at the new position
            const target_terrain = map.getTerrainAt(new_x, new_y);
            const target_effects = TerrainEffect.forAgentAndTerrain(self.type, target_terrain);
            
            // Determine if movement is allowed based on probability
            const move_prob = target_effects.movement_prob;
            const random_num = @mod(self.seed, 100);
            
            break :blk random_num < move_prob;
        };
        
        // Apply movement if allowed
        if (move_allowed) {
            // For x coordinate
            if (dx < 0) {
                // Moving left, ensure we don't go out of bounds
                const abs_dx = @abs(dx);
                if (self.x >= abs_dx) {
                    self.x -= @intCast(abs_dx);
                } else {
                    self.x = 0;
                }
            } else if (dx > 0) {
                // Moving right, no need to check for underflow
                self.x += @intCast(dx);
            }
            
            // For y coordinate
            if (dy < 0) {
                // Moving up, ensure we don't go out of bounds
                const abs_dy = @abs(dy);
                if (self.y >= abs_dy) {
                    self.y -= @intCast(abs_dy);
                } else {
                    self.y = 0;
                }
            } else if (dy > 0) {
                // Moving down, no need to check for underflow
                self.y += @intCast(dy);
            }
            
            // Energy consumption includes base cost plus terrain cost
            const moved = dx != 0 or dy != 0;
            const energy_cost: u8 = if (moved) blk: {
                var base_cost: u8 = 0;
                
                // Base cost depends on agent type
                switch (self.type) {
                    .Explorer => base_cost = 1, // Explorers are efficient
                    .Settler => base_cost = 2, // Settlers consume moderate energy
                    .Builder => base_cost = 3, // Builders are less efficient
                    .Farmer => base_cost = 2, // Farmers are moderately efficient
                    .Miner => base_cost = 4, // Miners consume the most energy
                    .Scout => base_cost = 1, // Scouts are energy-efficient
                }
                
                // Apply distance factor
                const distance_factor = @max(@abs(dx), @abs(dy));
                var result = base_cost * @as(u8, @intCast(distance_factor));
                
                // Add terrain movement cost
                const new_terrain = map.getTerrainAt(self.x, self.y);
                const new_effects = TerrainEffect.forAgentAndTerrain(self.type, new_terrain);
                result += new_effects.movement_cost;
                
                break :blk @min(result, 20); // Cap at 20 to prevent excessive energy drain
            } else 0;
            
            // Ensure we don't underflow
            if (self.energy > energy_cost) {
                self.energy -= energy_cost;
            } else {
                self.energy = 0;
            }
        }
    }
};