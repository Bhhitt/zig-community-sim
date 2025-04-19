const std = @import("std");
pub fn main() void {
    const a: usize = 42;
    // Try the OLD syntax for Zig <= 0.10
    const b: i32 = @intCast(i32)(a);
    std.debug.print("b = {}\n", .{b});
}
