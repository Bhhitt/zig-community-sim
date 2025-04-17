const std = @import("std");
const Agent = @import("agent").Agent;
const Interaction = @import("agent").Interaction;
const Map = @import("map").Map;
const Terrain = @import("terrain").Terrain;
const AgentType = @import("agent_type").AgentType;
const RenderConfig = @import("render_config").RenderConfig;
const AppInput = @import("input_handler").AppInput;
const input_handler = @import("input_handler");
const build_options = @import("build_options");

// Try to determine if SDL is available
// We'll use a compile-time variable to check
const has_sdl = build_options.USE_SDL;

// If SDL is available, use the SDL renderer, otherwise use the dummy renderer
pub const SdlRenderer = if (has_sdl) 
    @import("sdl_renderer").SdlRenderer
else 
    DummyRenderer;

// Dummy renderer that doesn't use SDL - used as fallback
pub const DummyRenderer = struct {
    width: i32,
    height: i32,
    initialized: bool,
    config: RenderConfig,

    pub fn init(map_width: usize, map_height: usize) !DummyRenderer {
        const config = RenderConfig.init();
        
        // Calculate window dimensions based on map size and cell size
        const width = @as(i32, @intCast(map_width * @as(usize, @intCast(config.cell_size)) + 2 * @as(usize, @intCast(config.window_padding))));
        const height = @as(i32, @intCast(map_height * @as(usize, @intCast(config.cell_size)) + 2 * @as(usize, @intCast(config.window_padding))));
        
        std.debug.print("\nWARNING: Using dummy renderer because SDL3 is not available\n", .{});
        std.debug.print("To use the real SDL renderer, make sure SDL3 is installed and enable it in the build\n", .{});
        std.debug.print("The simulation will run in text mode only\n\n", .{});
        
        return DummyRenderer{
            .width = width,
            .height = height,
            .initialized = true,
            .config = config,
        };
    }
    
    pub fn deinit(self: *DummyRenderer) void {
        self.initialized = false;
    }
    
    // Call this at the beginning of each frame
    pub fn startFrame(self: DummyRenderer) void {
        _ = self;
    }
    
    // Call this at the end of each frame
    pub fn endFrame(self: DummyRenderer) void {
        _ = self;
    }
    
    // Process SDL events and return app input state
    pub fn processEvents(self: DummyRenderer, spawn_mode: bool, current_paused: bool) AppInput {
        _ = self; // Unused, but kept for method syntax
        _ = spawn_mode;
        
        // This is a very simple implementation for the dummy renderer
        // Read a single key press from stdin without blocking
        const input = input_handler.readKeyboardInput();
        
        // Process the key
        const quit = input == 'q';
        const paused = if (input == 'p') !current_paused else current_paused;
        const step = input == 'n' and current_paused;
        const add_benchmark = input == 'b';
        const add_stress_test = input == 's';
        
        // Return the input state
        return .{
            .quit = quit,
            .paused = paused, 
            .step = step,
            .agent_type_changed = false,
            .selected_agent_type = .Settler,
            .toggle_spawn_mode = false,
            .spawn_requested = false,
            .mouse_x = 0,
            .mouse_y = 0,
            .add_benchmark_agents = add_benchmark,
            .add_stress_test_agents = add_stress_test,
        };
    }
    
    // Helper functions to access renderer constants
    pub fn cellSize(self: DummyRenderer) i32 {
        return self.config.cell_size;
    }
    
    pub fn windowPadding(self: DummyRenderer) i32 {
        return self.config.window_padding;
    }
    
    // Render the entire simulation - does nothing in headless mode
    pub fn renderSimulation(self: DummyRenderer, map: Map, agents: []const Agent, interactions: []const Interaction) void {
        _ = self;
        _ = map;
        _ = agents;
        _ = interactions;
    }
    
    // Render simulation status information - does nothing in headless mode
    pub fn renderSimulationStatus(
        self: DummyRenderer,
        step_count: usize,
        paused: bool,
        spawn_mode: bool,
        selected_agent_type: AgentType,
        agent_count: usize,
        fps: f32
    ) void {
        _ = self;
        _ = step_count;
        _ = paused;
        _ = spawn_mode;
        _ = selected_agent_type;
        _ = agent_count;
        _ = fps;
    }
};

// Export the SdlRenderer type so it can be used elsewhere
pub const RealSdlRenderer = SdlRenderer;