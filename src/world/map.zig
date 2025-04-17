const std = @import("std");
const Allocator = std.mem.Allocator;
const Agent = @import("agent").Agent;
const Interaction = @import("agent").Interaction;
pub const Terrain = @import("terrain").Terrain;

pub const Map = struct {
    width: usize,
    height: usize,
    grid: []Terrain,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: usize, height: usize) !Map {
        const grid = try allocator.alloc(Terrain, width * height);
        // Initialize with empty terrain
        for (grid) |*cell| {
            cell.* = .Empty;
        }

        return Map{
            .width = width,
            .height = height,
            .grid = grid,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.grid);
    }

    pub fn getTerrainAt(self: *const Map, x: usize, y: usize) Terrain {
        if (x >= self.width or y >= self.height) {
            return .Empty; // Default for out-of-bounds
        }
        return self.grid[y * self.width + x];
    }

    pub fn setTerrain(self: *Map, x: usize, y: usize, terrain: Terrain) void {
        if (x >= self.width or y >= self.height) {
            return; // Ignore out-of-bounds
        }
        self.grid[y * self.width + x] = terrain;
    }
    
    // Print the map to the terminal with agents and interactions
    pub fn print(self: *const Map, agents: []const Agent, interactions: []const Interaction) !void {
        const stdout = std.io.getStdOut().writer();
        
        // First, create a grid of terrain characters
        var display_grid = try self.allocator.alloc(u8, self.width * self.height);
        defer self.allocator.free(display_grid);
        
        // Fill with terrain symbols
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const terrain = self.getTerrainAt(x, y);
                const symbol: u8 = switch (terrain) {
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
            if (agent.x < self.width and agent.y < self.height) {
                display_grid[agent.y * self.width + agent.x] = agent.getSymbol();
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
            // Find agent symbols
            var agent1_symbol: u8 = '?';
            var agent2_symbol: u8 = '?';
            
            for (agents) |agent| {
                if (agent.id == interaction.agent1_id) {
                    agent1_symbol = agent.getSymbol();
                } else if (agent.id == interaction.agent2_id) {
                    agent2_symbol = agent.getSymbol();
                }
            }
            
            try stdout.print("  {c} <-> {c} ({s}, {d} ticks left)\n", 
                .{
                    agent1_symbol, 
                    agent2_symbol, 
                    @tagName(interaction.type), 
                    interaction.duration
                }
            );
        }
        
        // Print legend
        try stdout.print("\nLegend: [Space]=Empty [,]=Grass [F]=Forest [M]=Mountain [W]=Water\n", .{});
        try stdout.print("Agents: [S]=Settler [E]=Explorer [B]=Builder [F]=Farmer [M]=Miner [C]=Scout\n", .{});
    }
    
    // Save the map state to a file
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
            if (agent.x < self.width and agent.y < self.height) {
                display_grid[agent.y * self.width + agent.x] = agent.getSymbol();
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
                    agent.x, 
                    agent.y, 
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