const std = @import("std");

// Configuration constants
pub const RenderConfig = struct {
    cell_size: i32,
    window_padding: i32,
    
    pub fn init() RenderConfig {
        return .{
            .cell_size = 20, // Size of each cell in pixels
            .window_padding = 20, // Padding around the grid
        };
    }
};