const std = @import("std");

// Type representing directional movement
pub const Movement = struct {
    dx: i8,
    dy: i8,
    
    pub fn none() Movement {
        return .{ .dx = 0, .dy = 0 };
    }
    
    pub fn cardinal(direction: u8) Movement {
        return switch (direction) {
            0 => .{ .dx = 1, .dy = 0 },  // East
            1 => .{ .dx = 0, .dy = 1 },  // South
            2 => .{ .dx = -1, .dy = 0 }, // West
            3 => .{ .dx = 0, .dy = -1 }, // North
            else => .{ .dx = 0, .dy = 0 }
        };
    }
    
    pub fn diagonal(direction: u8) Movement {
        return switch (direction) {
            0 => .{ .dx = 1, .dy = 1 },   // Southeast
            1 => .{ .dx = -1, .dy = 1 },  // Southwest
            2 => .{ .dx = -1, .dy = -1 }, // Northwest
            3 => .{ .dx = 1, .dy = -1 },  // Northeast
            else => .{ .dx = 0, .dy = 0 }
        };
    }
    
    pub fn scale(self: Movement, factor: i8) Movement {
        return .{
            .dx = self.dx * factor,
            .dy = self.dy * factor,
        };
    }
    
    pub fn isMoving(self: Movement) bool {
        return self.dx != 0 or self.dy != 0;
    }
};

// Defines movement tendencies for different agent types
pub const MovementTendency = struct {
    move_chance: u8,              // Chance of moving (out of 100)
    direction_preference: u8,     // Tendency to move in certain directions (0-10)
    path_coherence: u8,           // Tendency to maintain direction (0-10)
    home_tendency: u8,            // Tendency to return to a home point (0-10)
    double_step_chance: u8,       // Chance to move 2 spaces (out of 100)
    all_direction_movement: bool, // Can move in 8 directions vs just 4
};

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

// Calculate new position with boundary checks
pub fn calculateNewPosition(
    x: usize, 
    y: usize, 
    dx: i8, 
    dy: i8, 
    map_width: usize, 
    map_height: usize
) struct { x: usize, y: usize } {
    var new_x = x;
    var new_y = y;
    
    // Apply x movement with bounds checking
    if (dx < 0) {
        const abs_dx = @abs(dx);
        if (new_x >= abs_dx) {
            new_x -= @intCast(abs_dx);
        } else {
            new_x = 0;
        }
    } else if (dx > 0) {
        new_x = @min(new_x + @as(usize, @intCast(dx)), map_width - 1);
    }
    
    // Apply y movement with bounds checking
    if (dy < 0) {
        const abs_dy = @abs(dy);
        if (new_y >= abs_dy) {
            new_y -= @intCast(abs_dy);
        } else {
            new_y = 0;
        }
    } else if (dy > 0) {
        new_y = @min(new_y + @as(usize, @intCast(dy)), map_height - 1);
    }
    
    return .{ .x = new_x, .y = new_y };
}

// Function to generate a randomized seed
pub fn generateRandomSeed() u64 {
    return std.crypto.random.int(u64);
}

// Utility function to update a seed based on time and ID
pub fn updateSeed(seed: u64, id: usize) u64 {
    const timestamp = @as(u64, @bitCast(std.time.milliTimestamp()));
    return (seed +% timestamp) *% 6364136223846793005 +% id;
}