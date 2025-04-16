const std = @import("std");
const testing = std.testing;
const Map = @import("map.zig").Map;
const Terrain = @import("map.zig").Terrain;
const Agent = @import("agent.zig").Agent;

test "Map init" {
    const allocator = testing.allocator;
    var map = try Map.init(allocator, 10, 5);
    defer map.deinit();
    
    try testing.expectEqual(@as(usize, 10), map.width);
    try testing.expectEqual(@as(usize, 5), map.height);
    try testing.expectEqual(@as(usize, 50), map.terrain.len);
}

test "Map getTerrainAt" {
    const allocator = testing.allocator;
    var map = try Map.init(allocator, 10, 5);
    defer map.deinit();
    
    // Test valid coordinates
    _ = map.getTerrainAt(5, 2);
    
    // Test out of bounds (should return Empty)
    try testing.expectEqual(Terrain.Empty, map.getTerrainAt(100, 100));
}

test "Map setTerrainAt" {
    const allocator = testing.allocator;
    var map = try Map.init(allocator, 10, 5);
    defer map.deinit();
    
    // Set a specific terrain type
    map.setTerrainAt(5, 2, .Forest);
    try testing.expectEqual(Terrain.Forest, map.getTerrainAt(5, 2));
    
    // Test setting out of bounds (should do nothing)
    map.setTerrainAt(100, 100, .Mountain);
}