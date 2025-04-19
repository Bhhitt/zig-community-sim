const std = @import("std");
const AppConfig = @import("config").AppConfig;
const AgentType = @import("agent_type").AgentType;
const Simulation = @import("simulation").Simulation;
const SdlRenderer = @import("renderer").SdlRenderer;
const StatsWindow = @import("stats_window").StatsWindow;

pub const App = struct {
    allocator: std.mem.Allocator,
    config: AppConfig,
    simulation: Simulation,
    sdl_renderer: ?SdlRenderer,
    stats_window: ?StatsWindow,
    
    // Application state
    paused: bool,
    step_once: bool,
    spawn_mode: bool,
    selected_agent_type: AgentType,
    quit: bool,
    
    // Performance tracking
    step_count: usize,
    frames_since_check: usize,
    last_performance_check: i64,
    current_fps: f32,
    
    pub fn init(allocator: std.mem.Allocator, config: AppConfig) !App {
        // Initialize simulation
        var simulation = try Simulation.init(allocator, config.map_width, config.map_height, config);
        errdefer simulation.deinit();
        
        // Initialize SDL renderer if enabled
        var sdl_renderer: ?SdlRenderer = null;
        var stats_window: ?StatsWindow = null;
        if (config.use_sdl) {
            sdl_renderer = try SdlRenderer.init(config.map_width, config.map_height);
            stats_window = try StatsWindow.init();
        }
        
        return App{
            .allocator = allocator,
            .config = config,
            .simulation = simulation,
            .sdl_renderer = sdl_renderer,
            .stats_window = stats_window,
            .paused = false,
            .step_once = false,
            .spawn_mode = false,
            .selected_agent_type = .Settler,
            .quit = false,
            .step_count = 0,
            .frames_since_check = 0,
            .last_performance_check = std.time.milliTimestamp(),
            .current_fps = 0,
        };
    }
    
    pub fn deinit(self: *App) void {
        self.simulation.deinit();
        
        if (self.sdl_renderer) |*renderer| {
            renderer.deinit();
        }
        
        if (self.stats_window) |*window| {
            window.deinit();
        }
    }
    
    pub fn run(self: *App) !void {
        // Main loop
        const max_steps: ?usize = @import("root").max_steps;
        while (!self.quit) {
            try self.processFrame(self.config);
            
            // Check if we've reached the maximum number of steps
            if (max_steps) |steps| {
                if (self.step_count >= steps) {
                    self.quit = true;
                }
            }
        }
        
        // Print final state and save map to file
        try self.simulation.saveMapToFile("map_state.txt");
    }
    
    fn processFrame(self: *App, config: AppConfig) !void {
        if (config.use_sdl) {
            try self.processFrameWithSdl(config);
        } else {
            try self.processFrameHeadless(config);
        }
    }
    
    fn processFrameHeadless(self: *App, config: AppConfig) !void {
        // Update simulation
        if (!self.paused or self.step_once) {
            try self.simulation.update(self.allocator, config);
            self.step_count += 1;
            self.frames_since_check += 1;
            self.step_once = false;
            
            // Calculate performance
            const current_time = std.time.milliTimestamp();
            const elapsed = current_time - self.last_performance_check;
            
            if (elapsed >= 1000) {
                self.current_fps = @as(f32, @floatFromInt(self.frames_since_check)) * 1000.0 / @as(f32, @floatFromInt(elapsed));
                self.frames_since_check = 0;
                self.last_performance_check = current_time;
            }
        }
        
        // Add delay
        std.time.sleep(config.running_delay_ms * std.time.ns_per_ms);
    }
    
    fn processFrameWithSdl(self: *App, config: AppConfig) !void {
        if (self.sdl_renderer) |*renderer| {
            // Process inputs
            const app_input = renderer.processEvents(self.spawn_mode, self.paused, self.config.map_width, self.config.map_height);
            self.quit = app_input.quit;
            self.paused = app_input.paused;
            self.step_once = app_input.step;
            
            // Handle agent type selection
            if (app_input.agent_type_changed) {
                self.selected_agent_type = app_input.selected_agent_type;
            }
            
            // Toggle spawn mode
            if (app_input.toggle_spawn_mode) {
                self.spawn_mode = !self.spawn_mode;
            }
            
            // Spawn agent if requested
            if (app_input.spawn_requested and self.spawn_mode) {
                // Convert screen coordinates to map coordinates
                const map_x = @divFloor(app_input.mouse_x - renderer.windowPadding(), renderer.cellSize());
                const map_y = @divFloor(app_input.mouse_y - renderer.windowPadding(), renderer.cellSize());
                
                // Make sure coordinates are within map bounds
                if (map_x >= 0 and map_x < config.map_width and map_y >= 0 and map_y < config.map_height) {
                    try self.simulation.spawnAgent(.{
                        .x = @intCast(map_x),
                        .y = @intCast(map_y),
                        .type = self.selected_agent_type,
                        .health = 100,
                        .energy = 100,
                    });
                }
            }
            
            // Handle benchmark and stress test requests
            if (app_input.add_benchmark_agents) {
                try self.addRandomAgents(10);
            }
            
            if (app_input.add_stress_test_agents) {
                try self.addRandomAgents(100);
            }
            
            // Update simulation if not paused or if step requested
            if (!self.paused or self.step_once) {
                try self.simulation.update(self.allocator, config);
                self.step_count += 1;
                self.frames_since_check += 1;
                self.step_once = false;
                
                // Calculate performance metrics
                const current_time = std.time.milliTimestamp();
                const elapsed = current_time - self.last_performance_check;
                
                if (elapsed >= 1000) {
                    self.current_fps = @as(f32, @floatFromInt(self.frames_since_check)) * 1000.0 / @as(f32, @floatFromInt(elapsed));
                    
                    self.frames_since_check = 0;
                    self.last_performance_check = current_time;
                }
            }
            
            // Render
            renderer.startFrame();
            renderer.renderSimulation(self.simulation.map, self.simulation.agents.items, self.simulation.interaction_system.getInteractions());
            renderer.renderSimulationStatus(
                self.step_count, 
                self.paused, 
                self.spawn_mode, 
                self.selected_agent_type, 
                self.simulation.agents.items.len,
                self.current_fps
            );
            renderer.endFrame();
            
            // After main window rendering, update stats window if present
            if (self.stats_window) |*stats| {
                stats.render(self.simulation.agents.items, self.simulation.interaction_system.getInteractions());
            }
            
            // Add a small delay to control simulation speed
            if (!self.paused) {
                std.time.sleep(config.running_delay_ms * std.time.ns_per_ms);
            } else {
                std.time.sleep(config.paused_delay_ms * std.time.ns_per_ms);
            }
        }
    }
    
    // Helper function to add random agents for benchmarking
    fn addRandomAgents(self: *App, count: usize) !void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const x = std.crypto.random.int(usize) % self.config.map_width;
            const y = std.crypto.random.int(usize) % self.config.map_height;
            const type_idx = std.crypto.random.int(u8) % 6;
            const agent_type = switch (type_idx) {
                0 => AgentType.Settler,
                1 => AgentType.Explorer,
                2 => AgentType.Builder,
                3 => AgentType.Farmer,
                4 => AgentType.Miner,
                5 => AgentType.Scout,
                else => AgentType.Settler,
            };
            const health = 75 + (std.crypto.random.int(u8) % 51); // 75-125
            const energy = 75 + (std.crypto.random.int(u8) % 51); // 75-125
            try self.simulation.spawnAgent(.{
                .x = x,
                .y = y,
                .type = agent_type,
                .health = health,
                .energy = energy,
            });
        }
    }
};