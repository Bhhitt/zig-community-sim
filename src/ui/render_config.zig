// RenderConfig defines UI rendering constants for the simulation.
const std = @import("std");

/// Configuration constants for rendering the simulation UI.
pub const RenderConfig = struct {
    /// Size of each cell in pixels.
    cell_size: i32,
    /// Padding around the grid.
    window_padding: i32,
    
    /// Returns a default RenderConfig instance.
    pub fn init() RenderConfig {
        return .{
            // Dynamically scale cell size and padding for large maps
            .cell_size = 20,
            .window_padding = 20,
        };
    }

    /// Returns a RenderConfig instance based on the screen size.
    pub fn initForScreen(map_width: usize, map_height: usize, screen_width: i32, screen_height: i32) RenderConfig {
        // Try to fit the map within the given screen size (minus a margin)
        const margin = 40;
        const avail_width = screen_width - margin;
        const avail_height = screen_height - margin;
        // Compute max cell size that fits map in window
        const cell_size_w = @divTrunc(avail_width, @as(i32, @intCast(map_width)));
        const cell_size_h = @divTrunc(avail_height, @as(i32, @intCast(map_height)));
        var cell_size = if (cell_size_w < cell_size_h) cell_size_w else cell_size_h;
        // Set a more reasonable minimum cell size for visibility
        if (cell_size < 8) cell_size = 8;
        // Padding for aesthetics
        const window_padding: i32 = @divTrunc(margin, 2);
        return .{
            .cell_size = cell_size,
            .window_padding = window_padding,
        };
    }
};