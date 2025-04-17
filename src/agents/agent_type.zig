const std = @import("std");
const movement_types = @import("movement_types");
const MovementTendency = movement_types.MovementTendency;
const MovementPattern = movement_types.MovementPattern;

pub const AgentType = enum {
    Settler,
    Explorer,
    Builder,
    Farmer,
    Miner,
    Scout,
    
    pub fn getSymbol(self: AgentType) u8 {
        return switch (self) {
            .Settler => 'S',
            .Explorer => 'E',
            .Builder => 'B',
            .Farmer => 'F',
            .Miner => 'M',
            .Scout => 'C',  // Scout uses 'C' for cartographer
        };
    }
    
    pub fn getBaseCost(self: AgentType) u8 {
        return switch (self) {
            .Explorer => 1, // Explorers are efficient
            .Settler => 2,  // Settlers consume moderate energy
            .Builder => 3,  // Builders are less efficient
            .Farmer => 2,   // Farmers are moderately efficient
            .Miner => 4,    // Miners consume the most energy
            .Scout => 1,    // Scouts are energy-efficient
        };
    }
    
    // Returns the movement tendency of each agent type
    pub fn getMovementTendency(self: AgentType) MovementTendency {
        return switch (self) {
            .Settler => .{
                .move_chance = 30,
                .direction_preference = 2,
                .path_coherence = 3,
                .home_tendency = 8,
                .double_step_chance = 0,
                .all_direction_movement = false,
            },
            .Explorer => .{
                .move_chance = 90,
                .direction_preference = 5,
                .path_coherence = 8,
                .home_tendency = 1,
                .double_step_chance = 15,
                .all_direction_movement = false,
            },
            .Builder => .{
                .move_chance = 50,
                .direction_preference = 7,
                .path_coherence = 4,
                .home_tendency = 5,
                .double_step_chance = 0,
                .all_direction_movement = false,
            },
            .Farmer => .{
                .move_chance = 40,
                .direction_preference = 3,
                .path_coherence = 3,
                .home_tendency = 7,
                .double_step_chance = 0,
                .all_direction_movement = false,
            },
            .Miner => .{
                .move_chance = 80,
                .direction_preference = 6,
                .path_coherence = 5,
                .home_tendency = 3,
                .double_step_chance = 0,
                .all_direction_movement = true,
            },
            .Scout => .{
                .move_chance = 95,
                .direction_preference = 2,
                .path_coherence = 2,
                .home_tendency = 0,
                .double_step_chance = 4,
                .all_direction_movement = true,
            },
        };
    }
    
    // Get the movement pattern for this agent type
    pub fn getMovementPattern(self: AgentType) MovementPattern {
        return switch (self) {
            .Settler => .{
                .move_chance = 30,      // 30% chance to move
                .can_move_diagonally = false,
                .can_double_step = false,
                .direction_change_rate = 100, // Direction change rate (percent)
                .tendency_to_stay = 70,  // High tendency to stay in place
                .base_energy_cost = 2,
            },
            .Explorer => .{
                .move_chance = 90,      // 90% chance to move
                .can_move_diagonally = false,
                .can_double_step = true,
                .double_step_chance = 14, // 1/7 chance (about 14%)
                .direction_change_rate = 25, // Direction changes less frequently
                .directional_bias = .{ .east = 33, .west = 33, .north = 17, .south = 17 }, // Bias east-west
                .base_energy_cost = 1,
            },
            .Builder => .{
                .move_chance = 50,
                .can_move_diagonally = false,
                .pattern_based = true,  // Builders use pattern-based movement
                .tendency_to_stay = 50, // Medium tendency to stay in place
                .base_energy_cost = 3,
            },
            .Farmer => .{
                .move_chance = 40,
                .can_move_diagonally = false,
                .home_seeking = true,   // Farmers occasionally return to their "home"
                .home_seeking_chance = 5, // 5% chance to seek home
                .tendency_to_stay = 60, // High tendency to stay in place
                .base_energy_cost = 2,
            },
            .Miner => .{
                .move_chance = 80,
                .can_move_diagonally = true,
                .diagonal_chance = 7,   // About 7% chance to move diagonally
                .tendency_to_stay = 20, // Lower tendency to stay in place
                .base_energy_cost = 4,
            },
            .Scout => .{
                .move_chance = 95,      // Almost always moving
                .can_move_diagonally = true,
                .diagonal_chance = 50,  // 50% chance to move diagonally
                .can_double_step = true,
                .double_step_chance = 4, // 4% chance (1/25)
                .spiral_movement = true, // Scouts use spiral-like movement patterns
                .base_energy_cost = 1,
            },
        };
    }
};