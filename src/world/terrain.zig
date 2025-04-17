const std = @import("std");

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

pub const TerrainGenerator = struct {
    pub fn generateTerrain(
        terrain: []Terrain, 
        width: usize, 
        height: usize, 
        seed_value: ?u64
    ) !void {
        // First, fill with mostly empty terrain as a base
        for (terrain) |*cell| {
            cell.* = .Empty;
        }
        
        // Use a timestamp-based seed for randomness if none provided
        var seed: u64 = seed_value orelse @as(u64, @bitCast(std.time.milliTimestamp()));
        
        // Generate coherent terrain features
        // 1. Create a few clusters of grass
        try generateTerrainFeature(terrain, width, height, .Grass, 4, 20, &seed);
        
        // 2. Create some forest clusters (smaller number, smaller size)
        try generateTerrainFeature(terrain, width, height, .Forest, 3, 12, &seed);
        
        // 3. Create a mountain range
        try generateTerrainFeature(terrain, width, height, .Mountain, 1, 8, &seed);
        
        // 4. Create a water body (like a lake or river)
        try generateTerrainFeature(terrain, width, height, .Water, 2, 15, &seed);
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
};