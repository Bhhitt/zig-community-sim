const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const random = std.crypto.random;
const agent_mod = @import("agent");
const map_mod = @import("map");
const config = @import("config");
const Map = map_mod.Map;
const Terrain = map_mod.Terrain;
const Agent = agent_mod.Agent;
const AgentType = agent_mod.AgentType;

// Utility structure to help with map-based tests
pub const TestMap = struct {
    map: Map,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, width: usize, height: usize) !TestMap {
        const map = try Map.init(allocator, width, height, config.AppConfig{});
        return TestMap{
            .map = map,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *TestMap) void {
        self.map.deinit();
    }
    
    // Create a standard test map with four quadrants of different terrain
    pub fn createQuadrantMap(self: *TestMap) void {
        const width = self.map.width;
        const height = self.map.height;
        
        for (0..width) |x| {
            for (0..height) |y| {
                if (x < width / 2 and y < height / 2) {
                    self.map.setTerrain(x, y, .Grass);
                } else if (x >= width / 2 and y < height / 2) {
                    self.map.setTerrain(x, y, .Forest);
                } else if (x < width / 2 and y >= height / 2) {
                    self.map.setTerrain(x, y, .Mountain);
                } else {
                    self.map.setTerrain(x, y, .Water);
                }
            }
        }
    }
    
    // Create a map with alternating terrain strips
    pub fn createStripedMap(self: *TestMap) void {
        const width = self.map.width;
        const height = self.map.height;
        
        for (0..width) |x| {
            for (0..height) |y| {
                const terrain_idx = @mod(x, 5);
                const terrain = @as(Terrain, @enumFromInt(terrain_idx));
                self.map.setTerrain(x, y, terrain);
            }
        }
    }
    
    // Create a map with random terrain
    pub fn createRandomMap(self: *TestMap, seed: u64) void {
        const width = self.map.width;
        const height = self.map.height;
        
        _ = seed; // We're using crypto.random instead of a PRNG with seed
        
        for (0..width) |x| {
            for (0..height) |y| {
                const terrain_idx = random.uintLessThan(u8, 5);
                const terrain = @as(Terrain, @enumFromInt(terrain_idx));
                self.map.setTerrain(x, y, terrain);
            }
        }
    }
};

// Utility to create a batch of agents for testing
pub fn createAgentBatch(
    allocator: Allocator,
    count: usize,
    startX: usize, 
    startY: usize,
    agent_type: AgentType
) !std.ArrayList(Agent) {
    var agents = std.ArrayList(Agent).init(allocator);
    errdefer agents.deinit();
    
    for (0..count) |i| {
        const agent = Agent.init(
            i, 
            startX + @mod(i, 5), 
            startY + @divFloor(i, 5), 
            agent_type, 
            100, 
            100
        );
        try agents.append(agent);
    }
    
    return agents;
}

// Test utility function
pub fn simulateAgentsOnMap(
    agents: *std.ArrayList(Agent),
    map: *Map,
    iterations: usize
) void {
    for (0..iterations) |_| {
        for (agents.items) |*agent| {
            agent.update(map);
        }
    }
}