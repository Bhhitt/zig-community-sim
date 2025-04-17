const std = @import("std");
const Agent = @import("agent.zig").Agent;
const Interaction = @import("agent.zig").Interaction;
const InteractionType = @import("agent.zig").InteractionType;

pub const Terrain = enum {
    Empty,
    Grass,
    Forest,
    Mountain,
    Water,
    
    pub fn getSymbol(self: Terrain) u8 {
        return switch (self) {
            .Empty => '.',
            .Grass => ',',
            .Forest => 'f',
            .Mountain => '^',
            .Water => '~',
        };
    }
};

pub const Map = struct {
    width: usize,
    height: usize,
    terrain: []Terrain,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Map {
        const terrain = try allocator.alloc(Terrain, width * height);
        
        // First, fill with mostly empty terrain as a base
        for (terrain) |*cell| {
            cell.* = .Empty;
        }
        
        // Use a timestamp-based seed for randomness
        var seed = @as(u64, @bitCast(std.time.milliTimestamp()));
        
        // Generate coherent terrain features
        // 1. Create a few clusters of grass
        try generateTerrainFeature(terrain, width, height, .Grass, 4, 20, &seed);
        
        // 2. Create some forest clusters (smaller number, smaller size)
        try generateTerrainFeature(terrain, width, height, .Forest, 3, 12, &seed);
        
        // 3. Create a mountain range
        try generateTerrainFeature(terrain, width, height, .Mountain, 1, 8, &seed);
        
        // 4. Create a water body (like a lake or river)
        try generateTerrainFeature(terrain, width, height, .Water, 2, 15, &seed);
        
        return Map{
            .width = width,
            .height = height,
            .terrain = terrain,
            .allocator = allocator,
        };
    }
    
    // Helper function to generate terrain features (clusters of similar terrain)
    fn generateTerrainFeature(
        terrain: []Terrain, 
        width: usize, 
        height: usize, 
        terrain_type: Terrain, 
        num_clusters: usize, 
        max_size: usize,
        seed: *u64
    ) !void {
        for (0..num_clusters) |_| {
            // Pick a random center for the cluster
            seed.* = (seed.* *% 6364136223846793005) +% 1;
            const center_x = @mod(seed.*, width);
            
            seed.* = (seed.* *% 6364136223846793005) +% 1;
            const center_y = @mod(seed.*, height);
            
            // Determine cluster size
            seed.* = (seed.* *% 6364136223846793005) +% 1;
            const size = @mod(seed.*, max_size) + 3; // At least 3 cells
            
            // Generate cells around the center in a roughly circular pattern
            for (0..width) |x| {
                for (0..height) |y| {
                    // Calculate distance from center (squared)
                    const dx = if (x > center_x) x - center_x else center_x - x;
                    const dy = if (y > center_y) y - center_y else center_y - y;
                    const distance_sq = dx * dx + dy * dy;
                    
                    // Cells within distance are part of the feature
                    if (distance_sq < size * size) {
                        // Some randomness to make edges irregular
                        seed.* = (seed.* *% 6364136223846793005) +% 1;
                        const random_factor = @mod(seed.*, 100);
                        
                        // Higher probability near center, lower at edges
                        const center_prob = 90;
                        const edge_prob = 40;
                        const prob_factor = center_prob - @as(usize, @intFromFloat(@as(f32, @floatFromInt(center_prob - edge_prob)) * 
                            @sqrt(@as(f32, @floatFromInt(distance_sq))) / @as(f32, @floatFromInt(size))));
                        
                        if (random_factor < prob_factor) {
                            const idx = y * width + x;
                            terrain[idx] = terrain_type;
                        }
                    }
                }
            }
        }
    }
    
    pub fn deinit(self: *Map) void {
        self.allocator.free(self.terrain);
    }
    
    pub fn getTerrainAt(self: Map, x: usize, y: usize) Terrain {
        if (x >= self.width or y >= self.height) {
            return .Empty;
        }
        return self.terrain[y * self.width + x];
    }
    
    pub fn setTerrainAt(self: *Map, x: usize, y: usize, terrain: Terrain) void {
        if (x < self.width and y < self.height) {
            self.terrain[y * self.width + x] = terrain;
        }
    }
    
    pub fn print(self: Map, agents: []const Agent, interactions: []const Interaction) !void {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var map_grid = try fba.allocator().alloc(u8, self.width * self.height);
        defer fba.allocator().free(map_grid);
        
        // Fill with terrain
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                map_grid[idx] = self.terrain[idx].getSymbol();
            }
        }
        
        // Place agents
        for (agents) |agent| {
            if (agent.x < self.width and agent.y < self.height) {
                map_grid[agent.y * self.width + agent.x] = agent.getSymbol();
            }
        }
        
        // Print the map
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                std.debug.print("{c}", .{map_grid[idx]});
            }
            std.debug.print("\n", .{});
        }
        
        // Print active interactions
        if (interactions.len > 0) {
            std.debug.print("\nActive Interactions:\n", .{});
            for (interactions) |interaction| {
                var agent1_idx: ?usize = null;
                var agent2_idx: ?usize = null;
                
                // Find the agent indices
                for (agents, 0..) |agent, i| {
                    if (agent.id == interaction.agent1_id) {
                        agent1_idx = i;
                    } else if (agent.id == interaction.agent2_id) {
                        agent2_idx = i;
                    }
                }
                
                if (agent1_idx != null and agent2_idx != null) {
                    const agent1 = agents[agent1_idx.?];
                    const agent2 = agents[agent2_idx.?];
                    std.debug.print("  {c}({},{}) {} {c}({},{}) - {s} ({})\n", 
                        .{
                            agent1.getSymbol(), 
                            agent1.x, 
                            agent1.y, 
                            interaction.type.getSymbol(), 
                            agent2.getSymbol(), 
                            agent2.x, 
                            agent2.y, 
                            @tagName(interaction.type),
                            interaction.duration
                        }
                    );
                }
            }
        }
    }
    
    pub fn saveToFile(self: Map, agents: []const Agent, interactions: []const Interaction, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        var writer = file.writer();
        
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var map_grid = try fba.allocator().alloc(u8, self.width * self.height);
        defer fba.allocator().free(map_grid);
        
        // Fill with terrain
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                map_grid[idx] = self.terrain[idx].getSymbol();
            }
        }
        
        // Place agents
        for (agents) |agent| {
            if (agent.x < self.width and agent.y < self.height) {
                map_grid[agent.y * self.width + agent.x] = agent.getSymbol();
            }
        }
        
        // Write to file
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                try writer.writeByte(map_grid[idx]);
            }
            try writer.writeByte('\n');
        }
        
        // Write active interactions
        if (interactions.len > 0) {
            try writer.writeAll("\nActive Interactions:\n");
            for (interactions) |interaction| {
                var agent1_idx: ?usize = null;
                var agent2_idx: ?usize = null;
                
                // Find the agent indices
                for (agents, 0..) |agent, i| {
                    if (agent.id == interaction.agent1_id) {
                        agent1_idx = i;
                    } else if (agent.id == interaction.agent2_id) {
                        agent2_idx = i;
                    }
                }
                
                if (agent1_idx != null and agent2_idx != null) {
                    const agent1 = agents[agent1_idx.?];
                    const agent2 = agents[agent2_idx.?];
                    
                    var buffer2: [100]u8 = undefined;
                    const message = try std.fmt.bufPrint(&buffer2, 
                        "  {c}({},{}) <-> {c}({},{}) - {s} ({})\n", 
                        .{
                            agent1.getSymbol(), 
                            agent1.x, 
                            agent1.y, 
                            agent2.getSymbol(), 
                            agent2.x, 
                            agent2.y, 
                            @tagName(interaction.type),
                            interaction.duration
                        }
                    );
                    try writer.writeAll(message);
                }
            }
        }
    }
};