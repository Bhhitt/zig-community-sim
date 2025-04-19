const std = @import("std");

// Application configuration
pub const AppConfig = struct {
    use_sdl: bool = true, // Set default to true to enable SDL
    map_width: usize = 50,
    map_height: usize = 60,

    // Delay settings
    running_delay_ms: u64 = 50, // Reduced from 100 to make it run faster
    paused_delay_ms: u64 = 16,

    // Food & hunger system
    food_spawn_chance: u8 = 2, // Initial food: percent chance per cell (0-100) -- made food much more scarce
    food_regrow_chance: f32 = 0.00001, // Per-step regrowth: probability per empty cell (0.0-1.0) -- made food much more scarce
    hunger_threshold: u8 = 80, // Hunger level for health penalty
    hunger_health_penalty: u8 = 1, // Health lost per step above threshold
    thread_count: usize = 1, // Number of threads for agent updates (default single-threaded)
    perception_radius: usize = 5, // How far agents can "see" for food and other agents
};
