const std = @import("std");

// Import all test files to run them
comptime {
    _ = @import("agent_tests.zig");
    _ = @import("interaction_tests.zig");
    _ = @import("movement_tests.zig");
    _ = @import("integration_tests.zig");
    _ = @import("parallel_tests.zig");
}

// Add agent and map as dependencies
comptime {
    _ = @import("agent");
    _ = @import("map");
    _ = @import("test_utils");
}

pub fn main() !void {
    std.debug.print("Running all agent tests...\n", .{});
}