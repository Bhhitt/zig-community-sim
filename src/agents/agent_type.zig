// AgentType module defines the types of agents and their movement logic in the simulation.
const std = @import("std");
const movement_types = @import("movement_types");
const MovementTendency = movement_types.MovementTendency;
const MovementPattern = movement_types.MovementPattern;

/// Represents the type of an agent in the simulation.
/// 
/// Each agent type has its own movement tendency and pattern, which determine how it moves in the simulation.
pub const AgentType = enum {
    /// A settler agent, which settles in a location and has moderate movement.
    Settler,
    /// An explorer agent, which explores the surroundings and has high movement.
    Explorer,
    /// A builder agent, which builds structures and has medium movement.
    Builder,
    /// A farmer agent, which farms resources and has moderate movement.
    Farmer,
    /// A miner agent, which mines resources and has high movement.
    Miner,
    /// A scout agent, which scouts the surroundings and has very high movement.
    Scout,

    /// Returns the symbol representing the agent type.
    /// 
    /// Each agent type has a unique symbol that can be used to identify it.
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

    /// Returns the base energy cost for the agent type.
    /// 
    /// Each agent type has a base energy cost that determines how much energy it consumes.
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

    /// Returns the movement tendency for the agent type.
    /// 
    /// The movement tendency determines how the agent moves in the simulation.
    pub fn getMovementTendency(self: AgentType) MovementTendency {
        return switch (self) {
            .Settler => .{
                .move_chance = 30,
                .direction_preference = 2,
                .path_coherence = 3,
                .home_tendency = 8,
                .double_step_chance = 5,
                .all_direction_movement = false,
            },
            .Explorer => .{
                .move_chance = 60,
                .direction_preference = 7,
                .path_coherence = 6,
                .home_tendency = 2,
                .double_step_chance = 10,
                .all_direction_movement = true,
            },
            .Builder => .{
                .move_chance = 20,
                .direction_preference = 2,
                .path_coherence = 8,
                .home_tendency = 6,
                .double_step_chance = 0,
                .all_direction_movement = false,
            },
            .Farmer => .{
                .move_chance = 40,
                .direction_preference = 5,
                .path_coherence = 5,
                .home_tendency = 8,
                .double_step_chance = 0,
                .all_direction_movement = false,
            },
            .Miner => .{
                .move_chance = 50,
                .direction_preference = 6,
                .path_coherence = 7,
                .home_tendency = 3,
                .double_step_chance = 15,
                .all_direction_movement = true,
            },
            .Scout => .{
                .move_chance = 80,
                .direction_preference = 9,
                .path_coherence = 2,
                .home_tendency = 1,
                .double_step_chance = 20,
                .all_direction_movement = true,
            },
        };
    }

    /// Returns the movement pattern for the agent type.
    pub fn getMovementPattern(self: AgentType) MovementPattern {
        return switch (self) {
            .Settler => .{
                .move_chance = 30,      // 30% chance to move
                .can_move_diagonally = false,
                .diagonal_chance = 0,
                .base_energy_cost = 2,
                .pattern_based = false,
                .spiral_movement = false,
                .home_seeking = true,
                .home_seeking_chance = 20,
                .directional_bias = .{ .north = 25, .south = 25, .east = 25, .west = 25 },
                .double_step_chance = 5,
                .smoothness = 0.7,
            },
            .Explorer => .{
                .move_chance = 90,
                .can_move_diagonally = true,
                .diagonal_chance = 30,
                .base_energy_cost = 1,
                .pattern_based = false,
                .spiral_movement = false,
                .home_seeking = false,
                .home_seeking_chance = 0,
                .directional_bias = .{ .north = 20, .south = 40, .east = 20, .west = 20 },
                .double_step_chance = 10,
                .smoothness = 0.2,
                .can_double_step = false,
            },
            .Builder => .{
                .move_chance = 20,
                .can_move_diagonally = false,
                .diagonal_chance = 0,
                .base_energy_cost = 3,
                .pattern_based = true,
                .spiral_movement = false,
                .home_seeking = false,
                .home_seeking_chance = 0,
                .directional_bias = .{ .north = 30, .south = 30, .east = 20, .west = 20 },
                .double_step_chance = 0,
                .smoothness = 0.95,
            },
            .Farmer => .{
                .move_chance = 40,
                .can_move_diagonally = false,
                .diagonal_chance = 0,
                .base_energy_cost = 2,
                .pattern_based = false,
                .spiral_movement = false,
                .home_seeking = true,
                .home_seeking_chance = 45,
                .directional_bias = .{ .north = 15, .south = 35, .east = 25, .west = 25 },
                .double_step_chance = 0,
                .smoothness = 0.6,
            },
            .Miner => .{
                .move_chance = 50,
                .can_move_diagonally = true,
                .diagonal_chance = 20,
                .base_energy_cost = 4,
                .pattern_based = false,
                .spiral_movement = false,
                .home_seeking = false,
                .home_seeking_chance = 0,
                .directional_bias = .{ .north = 25, .south = 25, .east = 25, .west = 25 },
                .double_step_chance = 15,
                .smoothness = 0.3,
            },
            .Scout => .{
                .move_chance = 80,
                .can_move_diagonally = true,
                .diagonal_chance = 70,
                .base_energy_cost = 1,
                .pattern_based = false,
                .spiral_movement = true,
                .home_seeking = false,
                .home_seeking_chance = 0,
                .directional_bias = .{ .north = 25, .south = 25, .east = 25, .west = 25 },
                .double_step_chance = 20,
                .smoothness = 0.05,
            },
        };
    }
};

pub const AgentTypeFields = @typeInfo(AgentType).@"enum".fields;