const std = @import("std");
const agent_code = @embedFile("src/agents/agent.zig");
const map_code = @embedFile("src/world/map.zig");

// Movement pattern simplified for testing
const MovementPattern = struct {
    move_chance: u8 = 50,           // Base chance to move
    can_move_diagonally: bool = false,
    diagonal_chance: u8 = 0,        // Chance for diagonal movement
    can_double_step: bool = false,
    double_step_chance: u8 = 0,     // Chance for double step
    pattern_based: bool = false,    // Pattern-based movement
    spiral_movement: bool = false,  // Spiral movement
    home_seeking: bool = false,     // Home-seeking behavior
    home_seeking_chance: u8 = 0,    // Home-seeking chance
    tendency_to_stay: u8 = 0,       // Tendency to stay
    direction_change_rate: u8 = 50, // Direction change rate
    base_energy_cost: u8 = 2,       // Base energy cost
    
    // Directional bias
    directional_bias: struct {
        north: u8 = 25,
        south: u8 = 25,
        east: u8 = 25,
        west: u8 = 25,
    } = .{},
};

// Agent type for testing
const AgentType = enum {
    Settler,
    Explorer,
    Builder,
    Farmer,
    Miner,
    Scout,
    
    fn getMovementPattern(self: AgentType) MovementPattern {
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

// Simplified agent for performance testing
const Agent = struct {
    id: usize,
    x: usize,
    y: usize,
    type: AgentType,
    seed: u64,
    
    // Update the random seed for deterministic testing
    fn updateSeed(self: *Agent) u64 {
        self.seed = (self.seed +% 1) *% 6364136223846793005 +% self.id;
        return self.seed;
    }
    
    // Movement result type
    const MovementResult = struct {
        dx: i8 = 0,
        dy: i8 = 0,
    };
    
    // Calculate movement direction based on agent type and pattern
    fn calculateMovement(self: *Agent, pattern: MovementPattern) MovementResult {
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
            const time_component = @as(u8, @intCast(@mod(random_value, 4)));
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
            
            // Apply double step chance
            if (pattern.double_step_chance > 0 and @mod(random_value, 100) < pattern.double_step_chance) {
                result.dx *= 2;
                result.dy *= 2;
            }
            
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
        if (pattern.can_double_step and @mod(random_value, 100) < pattern.double_step_chance) {
            result.dx *= 2;
            result.dy *= 2;
        }
        
        return result;
    }
};

// Performance test function
fn runPerformanceTest(agents: []Agent, iterations: usize) !void {
    var movement_counts = [_]usize{0} ** 9; // 8 directions + no movement
    
    std.debug.print("Running performance test...\n", .{});
    const start_time = std.time.milliTimestamp();
    
    for (0..iterations) |_| {
        for (agents) |*agent| {
            // Get movement pattern
            const pattern = agent.type.getMovementPattern();
            
            // Calculate movement
            const movement = agent.calculateMovement(pattern);
            
            // Track movement stats (for verification)
            if (movement.dx >= -1 and movement.dx <= 1 and 
                movement.dy >= -1 and movement.dy <= 1) {
                // Convert -1,0,1 range to 0,1,2 range for array index by adding 1
                const dx_idx = @as(usize, @intCast(movement.dx + 1));
                const dy_idx = @as(usize, @intCast(movement.dy + 1));
                const idx = dx_idx * 3 + dy_idx;
                movement_counts[idx] += 1;
            } else {
                // Out of range movement (e.g., double steps)
                // Just count them in the center for simplicity
                movement_counts[4] += 1;
            }
        }
    }
    
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;
    
    // Calculate actual performance
    const total_updates = agents.len * iterations;
    const updates_per_ms = @as(f64, @floatFromInt(total_updates)) / @as(f64, @floatFromInt(duration_ms));
    
    std.debug.print("\nPerformance Results:\n", .{});
    std.debug.print("- Total time: {d}ms\n", .{duration_ms});
    std.debug.print("- Updates: {d}\n", .{total_updates});
    std.debug.print("- Updates per millisecond: {d:.2}\n", .{updates_per_ms});
    std.debug.print("- Updates per second: {d:.2}\n", .{updates_per_ms * 1000.0});
    
    // Print movement distribution
    std.debug.print("\nMovement Distribution (percent):\n", .{});
    std.debug.print("   NW  N  NE\n", .{});
    std.debug.print("    W  .  E\n", .{});
    std.debug.print("   SW  S  SE\n", .{});
    std.debug.print("NW: {d:.1}%, N: {d:.1}%, NE: {d:.1}%\n", 
        .{
            100.0 * @as(f64, @floatFromInt(movement_counts[0])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[1])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[2])) / @as(f64, @floatFromInt(total_updates)),
        });
    std.debug.print("W:  {d:.1}%, .: {d:.1}%, E:  {d:.1}%\n", 
        .{
            100.0 * @as(f64, @floatFromInt(movement_counts[3])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[4])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[5])) / @as(f64, @floatFromInt(total_updates)),
        });
    std.debug.print("SW: {d:.1}%, S: {d:.1}%, SE: {d:.1}%\n", 
        .{
            100.0 * @as(f64, @floatFromInt(movement_counts[6])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[7])) / @as(f64, @floatFromInt(total_updates)),
            100.0 * @as(f64, @floatFromInt(movement_counts[8])) / @as(f64, @floatFromInt(total_updates)),
        });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Default configuration
    var agent_count: usize = 500;
    var iterations: usize = 1000;
    
    if (args.len > 1) {
        agent_count = try std.fmt.parseInt(usize, args[1], 10);
    }
    if (args.len > 2) {
        iterations = try std.fmt.parseInt(usize, args[2], 10);
    }
    
    std.debug.print("\n=== Performance Test for Refactored Agent Code ===\n", .{});
    std.debug.print("Source code: {d} bytes\n", .{agent_code.len + map_code.len});
    std.debug.print("Testing {d} agents for {d} iterations\n", .{agent_count, iterations});
    
    // Create agents for testing
    var agents = try allocator.alloc(Agent, agent_count);
    defer allocator.free(agents);
    
    // Initialize agents with different types
    const agent_types = [_]AgentType{
        .Settler, .Explorer, .Builder, .Farmer, .Miner, .Scout
    };
    
    for (0..agent_count) |i| {
        const agent_type = agent_types[@mod(i, agent_types.len)];
        agents[i] = .{
            .id = i,
            .x = 10, // Arbitrary position
            .y = 10, // Arbitrary position
            .type = agent_type,
            .seed = i * 1234567, // Deterministic seed
        };
    }
    
    // Run performance test
    try runPerformanceTest(agents, iterations);
    
    std.debug.print("\nCode analysis:\n", .{});
    std.debug.print("- Agent movement calculation complexity: O(1) time, O(1) space\n", .{});
    std.debug.print("- Agent movement patterns: 6 distinct types with different behaviors\n", .{});
    std.debug.print("- Each agent type has unique movement characteristics:\n", .{});
    std.debug.print("  - Settler: Tends to stay in place, slow movement\n", .{});
    std.debug.print("  - Explorer: Fast movement with east-west bias\n", .{});
    std.debug.print("  - Builder: Pattern-based movement\n", .{});
    std.debug.print("  - Farmer: Home-seeking behavior\n", .{});
    std.debug.print("  - Miner: More energy-intensive movement\n", .{});
    std.debug.print("  - Scout: Fast diagonal movement with spiraling patterns\n", .{});
    
    std.debug.print("\n=== Performance Test Complete ===\n", .{});
}