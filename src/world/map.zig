// Map module manages the simulation world grid, terrain, and agent placement.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Agent = @import("agent").Agent;
const Interaction = @import("agent").Interaction;
pub const Terrain = @import("terrain").Terrain;
const crypto_random = std.crypto.random;

const Thread = std.Thread;

/// Represents the simulation world grid, terrain, and agent placement.
pub const Map = struct {
    /// The width of the map grid.
    width: usize,
    /// The height of the map grid.
    height: usize,
    /// The 2D grid of terrain cells.
    grid: []Terrain,
    /// The food layer: 0 = no food, >0 = food present
    food_grid: []u8,
    /// Mutex for thread-safe access to the food grid
    food_mutex: Thread.Mutex = .{},
    /// The allocator used to manage map resources.
    allocator: Allocator,
    /// Reference to all agents for interaction targeting
    simulation_agents: ?[]Agent = null,

    /// Initializes a new map with the given dimensions, allocator, and configuration.
    ///
    /// Returns a new Map instance with the specified width, height, allocator, and configuration.
    pub fn init(allocator: Allocator, width: usize, height: usize, config: anytype) !Map {
        const grid = try allocator.alloc(Terrain, width * height);
        for (grid) |*cell| {
            cell.* = .Empty;
        }
        const food_grid = try allocator.alloc(u8, width * height);
        for (food_grid) |*food| {
            // Configurable chance of food per cell
            food.* = if (crypto_random.int(u8) % 100 < config.food_spawn_chance) 1 else 0;
        }
        return Map{
            .width = width,
            .height = height,
            .grid = grid,
            .food_grid = food_grid,
            .allocator = allocator,
        };
    }

    /// Deinitializes the map and frees resources.
    ///
    /// Releases the map's grid memory and any other allocated resources.
    pub fn deinit(self: *Map) void {
        self.allocator.free(self.grid);
        self.allocator.free(self.food_grid);
    }

    /// Returns the terrain at the given coordinates, or .Empty if out-of-bounds.
    ///
    /// Retrieves the terrain type at the specified x, y coordinates.
    pub fn getTerrainAt(self: *const Map, x: usize, y: usize) Terrain {
        if (x >= self.width or y >= self.height) {
            // std.debug.print("Terrain access out of bounds: ({d}, {d})\n", .{x, y});
            return .Empty; // Default for out-of-bounds
        }
        return self.grid[y * self.width + x];
    }

    /// Sets the terrain at the given coordinates, ignoring out-of-bounds.
    ///
    /// Updates the terrain type at the specified x, y coordinates.
    pub fn setTerrain(self: *Map, x: usize, y: usize, terrain: Terrain) void {
        if (x >= self.width or y >= self.height) {
            return; // Ignore out-of-bounds
        }
        self.grid[y * self.width + x] = terrain;
    }

    /// Returns the food value at the given coordinates, or 0 if out-of-bounds.
    pub fn getFoodAt(self: *const Map, x: usize, y: usize) u8 {
        if (x >= self.width or y >= self.height) {
            return 0;
        }
        // Lock for thread-safe access
        @constCast(self).food_mutex.lock();
        defer @constCast(self).food_mutex.unlock();
        
        return self.food_grid[y * self.width + x];
    }

    /// Sets the food value at the given coordinates, ignoring out-of-bounds.
    pub fn setFoodAt(self: *Map, x: usize, y: usize, food: u8) void {
        if (x >= self.width or y >= self.height) {
            return;
        }
        // Lock for thread-safe access
        self.food_mutex.lock();
        defer self.food_mutex.unlock();
        
        self.food_grid[y * self.width + x] = food;
    }

    /// Regrow food randomly on the map (called each simulation step)
    pub fn regrowFood(self: *Map, regrow_chance_per_cell: f32) void {
        // Lock once for the entire regrow operation to avoid excessive locking/unlocking
        self.food_mutex.lock();
        defer self.food_mutex.unlock();
        
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (x >= self.width or y >= self.height) continue;
                
                // Direct access to food_grid since we have the lock
                const index = y * self.width + x;
                if (self.food_grid[index] == 0) {
                    if (crypto_random.float(f32) < regrow_chance_per_cell) {
                        self.food_grid[index] = 1;
                    }
                }
            }
        }
    }

    /// Prints the map to the terminal with agents and interactions.
    ///
    /// Displays the map grid, agents, and interactions to the console.
    pub fn print(self: *const Map, agents: []const Agent, interactions: []const Interaction) !void {
        const stdout = std.io.getStdOut().writer();
        // First, create a grid of terrain characters
        var display_grid = try self.allocator.alloc(u8, self.width * self.height);
        defer self.allocator.free(display_grid);
        // Fill with terrain symbols, overlay food
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const terrain = self.getTerrainAt(x, y);
                const food = self.getFoodAt(x, y);
                const symbol: u8 = if (food > 0) '*' else switch (terrain) {
                    .Dirt => '.',
                    .Empty => ' ',
                    .Grass => ',',
                    .Forest => 'F',
                    .Mountain => 'M',
                    .Water => 'W',
                };
                display_grid[y * self.width + x] = symbol;
            }
        }
        // Place agents on the grid (agents overwrite food/terrain symbol)
        for (agents) |agent| {
            if (agent.x < @as(f32, @floatFromInt(self.width)) and agent.y < @as(f32, @floatFromInt(self.height))) {
                display_grid[@as(usize, @intFromFloat(agent.y)) * self.width + @as(usize, @intFromFloat(agent.x))] = agent.getSymbol();
            }
        }
        // Print the grid
        try stdout.print("\n", .{});
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                try stdout.print("{c}", .{display_grid[y * self.width + x]});
            }
            try stdout.print("\n", .{});
        }
        // Print interactions
        try stdout.print("\nActive Interactions ({d}):\n", .{interactions.len});
        for (interactions) |interaction| {
            try stdout.print("  {s}\n", .{interaction.toString()});
        }
    }

    /// Saves the map, agents, and interactions to a file.
    ///
    /// Writes the map grid, agents, and interactions to the specified file.
    pub fn saveToFile(self: *const Map, agents: []const Agent, interactions: []const Interaction, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        const writer = file.writer();
        
        // First, create a grid of terrain characters
        var display_grid = try self.allocator.alloc(u8, self.width * self.height);
        defer self.allocator.free(display_grid);
        
        // Fill with terrain symbols
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const terrain = self.getTerrainAt(x, y);
                const symbol: u8 = switch (terrain) {
                    .Dirt => '.',
                    .Empty => ' ',
                    .Grass => ',',
                    .Forest => 'F',
                    .Mountain => 'M',
                    .Water => 'W',
                };
                display_grid[y * self.width + x] = symbol;
            }
        }
        
        // Place agents on grid
        for (agents) |agent| {
            if (agent.x < @as(f32, @floatFromInt(self.width)) and agent.y < @as(f32, @floatFromInt(self.height))) {
                display_grid[@as(usize, @intFromFloat(agent.y)) * self.width + @as(usize, @intFromFloat(agent.x))] = agent.getSymbol();
            }
        }
        
        // Write the grid to file
        try writer.print("Map ({d}x{d}):\n", .{self.width, self.height});
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                try writer.print("{c}", .{display_grid[y * self.width + x]});
            }
            try writer.print("\n", .{});
        }
        
        // Write agent details
        try writer.print("\nAgents ({d}):\n", .{agents.len});
        for (agents) |agent| {
            try writer.print("  {c} ({s}): pos=({d},{d}), health={d}, energy={d}\n", 
                .{
                    agent.getSymbol(), 
                    @tagName(agent.type), 
                    @as(usize, @intFromFloat(agent.x)), 
                    @as(usize, @intFromFloat(agent.y)), 
                    agent.health, 
                    agent.energy
                }
            );
        }
        
        // Write interactions
        try writer.print("\nActive Interactions ({d}):\n", .{interactions.len});
        for (interactions) |interaction| {
            try writer.print("  Agent {d} <-> Agent {d} ({s}, {d} ticks left)\n", 
                .{
                    interaction.agent1_id, 
                    interaction.agent2_id, 
                    @tagName(interaction.type), 
                    interaction.duration
                }
            );
        }
    }
};