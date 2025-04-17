const std = @import("std");

// Describes how an agent type moves in the world
pub const MovementPattern = struct {
    // Movement probability
    move_chance: u8 = 50,           // Base chance to move (out of 100)
    
    // Movement style flags
    can_move_diagonally: bool = false,
    diagonal_chance: u8 = 0,        // Chance to make a move diagonal (out of 100)
    can_double_step: bool = false,
    double_step_chance: u8 = 0,     // Chance to move two steps at once (out of 100)
    pattern_based: bool = false,    // Uses geometric patterns for movement
    spiral_movement: bool = false,  // Uses spiral-like movement patterns
    home_seeking: bool = false,     // Occasionally moves toward a "home" position
    home_seeking_chance: u8 = 0,    // Chance to seek home (out of 100)
    
    // Movement tendencies
    tendency_to_stay: u8 = 0,       // Tendency to stay in current position (out of 100)
    direction_change_rate: u8 = 50, // How often direction changes (out of 100)
    
    // Directional bias (values should sum to 100)
    directional_bias: struct {
        north: u8 = 25,
        south: u8 = 25,
        east: u8 = 25,
        west: u8 = 25,
    } = .{},
    
    // Energy consumption
    base_energy_cost: u8 = 2,       // Base energy cost per movement
};