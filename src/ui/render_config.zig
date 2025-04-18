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
            .cell_size = 20, // Size of each cell in pixels
            .window_padding = 20, // Padding around the grid
        };
    }
};