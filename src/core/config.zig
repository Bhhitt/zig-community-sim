const std = @import("std");

// Application configuration
pub const AppConfig = struct {
    use_sdl: bool = false, // Set default to false to avoid SDL dependency
    map_width: usize = 60,
    map_height: usize = 30,
    
    // Delay settings
    running_delay_ms: u64 = 50,  // Reduced from 100 to make it run faster
    paused_delay_ms: u64 = 16,
};