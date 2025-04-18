const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const Agent = @import("agent").Agent;
const Interaction = @import("agent").Interaction;
const Map = @import("map").Map;
const Terrain = @import("terrain").Terrain;
const AgentType = @import("agent_type").AgentType;
const RenderConfig = @import("render_config").RenderConfig;
const AppInput = @import("input_handler").AppInput;

pub const SdlRenderer = struct {
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    width: i32,
    height: i32,
    initialized: bool,
    config: RenderConfig,

    pub fn init(map_width: usize, map_height: usize) !SdlRenderer {
        const config = RenderConfig.init();
        
        // Calculate window dimensions based on map size and cell size
        const width = @as(i32, @intCast(map_width * @as(usize, @intCast(config.cell_size)) + 2 * @as(usize, @intCast(config.window_padding))));
        const height = @as(i32, @intCast(map_height * @as(usize, @intCast(config.cell_size)) + 2 * @as(usize, @intCast(config.window_padding))));
        
        // Initialize SDL
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            std.debug.print("SDL_Init Error: {s}\n", .{c.SDL_GetError()});
            return error.SDLInitializationFailed;
        }
        std.debug.print("SDL3 initialized successfully!\n", .{});
        
        // Create window
        const window = c.SDL_CreateWindow(
            "Zig Community Simulation",
            width,
            height,
            0  // Default flags, window will be visible
        );
        
        if (window == null) {
            std.debug.print("SDL_CreateWindow Error: {s}\n", .{c.SDL_GetError()});
            c.SDL_Quit();
            return error.SDLCreateWindowFailed;
        }
        
        // Create renderer
        const renderer = c.SDL_CreateRenderer(window, null);
        if (renderer == null) {
            std.debug.print("SDL_CreateRenderer Error: {s}\n", .{c.SDL_GetError()});
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.SDLCreateRendererFailed;
        }
        
        std.debug.print("SDL renderer initialized\n", .{});
        
        return SdlRenderer{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .initialized = true,
            .config = config,
        };
    }
    
    pub fn deinit(self: *SdlRenderer) void {
        if (self.renderer) |renderer| {
            c.SDL_DestroyRenderer(renderer);
            self.renderer = null;
        }
        
        if (self.window) |window| {
            c.SDL_DestroyWindow(window);
            self.window = null;
        }
        
        c.SDL_Quit();
        self.initialized = false;
    }
    
    // Call this at the beginning of each frame
    pub fn startFrame(self: SdlRenderer) void {
        if (self.renderer) |renderer| {
            _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            _ = c.SDL_RenderClear(renderer);
        }
    }
    
    // Call this at the end of each frame
    pub fn endFrame(self: SdlRenderer) void {
        if (self.renderer) |renderer| {
            _ = c.SDL_RenderPresent(renderer);
        }
    }
    
    // Process SDL events and return app input state
    pub fn processEvents(self: SdlRenderer, spawn_mode: bool, current_paused: bool) AppInput {
        _ = self;
        
        var result = AppInput{
            .paused = current_paused,
        };
        
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    result.quit = true;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    // In SDL3, the keyboard event structure has changed
                    // Use event.key.keycode instead of event.key.keysym.sym
                    // SDL3 keyboard event structure is different
                    // For simplicity, let's use a hardcoded key check for now
                    const scancode = event.key.scancode;
                    
                    if (scancode == c.SDL_SCANCODE_ESCAPE) {
                        result.quit = true;
                    } else if (scancode == c.SDL_SCANCODE_SPACE) {
                        result.paused = !current_paused;
                    } else if (scancode == c.SDL_SCANCODE_RIGHT) {
                        if (current_paused) {
                            result.step = true;
                        }
                    } else if (scancode == c.SDL_SCANCODE_A) {
                        result.toggle_spawn_mode = true;
                    } else if (scancode == c.SDL_SCANCODE_B) {
                        result.add_benchmark_agents = true;
                    } else if (scancode == c.SDL_SCANCODE_S) {
                        result.add_stress_test_agents = true;
                    } else if (scancode == c.SDL_SCANCODE_1) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Settler;
                    } else if (scancode == c.SDL_SCANCODE_2) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Explorer;
                    } else if (scancode == c.SDL_SCANCODE_3) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Builder;
                    } else if (scancode == c.SDL_SCANCODE_4) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Farmer;
                    } else if (scancode == c.SDL_SCANCODE_5) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Miner;
                    } else if (scancode == c.SDL_SCANCODE_6) {
                        result.agent_type_changed = true;
                        result.selected_agent_type = .Scout;
                    }
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT and spawn_mode) {
                        result.spawn_requested = true;
                        result.mouse_x = @intFromFloat(event.button.x);
                        result.mouse_y = @intFromFloat(event.button.y);
                    }
                },
                else => {},
            }
        }
        
        return result;
    }
    
    // Helper functions to access renderer constants
    pub fn cellSize(self: SdlRenderer) i32 {
        return self.config.cell_size;
    }
    
    pub fn windowPadding(self: SdlRenderer) i32 {
        return self.config.window_padding;
    }
    
    // Define a common color struct
    const ColorRGB = struct {
        r: u8,
        g: u8,
        b: u8,
    };
    
    // Get color for a terrain type
    fn getTerrainColor(terrain: Terrain) ColorRGB {
        return switch (terrain) {
            .Empty => .{ .r = 40, .g = 40, .b = 40 },
            .Grass => .{ .r = 100, .g = 200, .b = 100 },
            .Forest => .{ .r = 34, .g = 139, .b = 34 },
            .Mountain => .{ .r = 139, .g = 137, .b = 137 },
            .Water => .{ .r = 30, .g = 144, .b = 255 },
        };
    }
    
    // Get color for an agent type
    fn getAgentColor(agent_type: AgentType) ColorRGB {
        return switch (agent_type) {
            .Settler => .{ .r = 255, .g = 255, .b = 255 },
            .Explorer => .{ .r = 255, .g = 215, .b = 0 },
            .Builder => .{ .r = 255, .g = 99, .b = 71 },
            .Farmer => .{ .r = 50, .g = 205, .b = 50 },
            .Miner => .{ .r = 169, .g = 169, .b = 169 },
            .Scout => .{ .r = 135, .g = 206, .b = 250 },
        };
    }
    
    // Render a cell at a given position
    fn renderCell(
        self: SdlRenderer, 
        x: usize, 
        y: usize, 
        color: ColorRGB
    ) void {
        if (self.renderer) |renderer| {
            const cell_size = self.config.cell_size;
            const padding = self.config.window_padding;
            
            const rect = c.SDL_FRect{
                .x = @floatFromInt(padding + @as(i32, @intCast(x)) * cell_size),
                .y = @floatFromInt(padding + @as(i32, @intCast(y)) * cell_size),
                .w = @floatFromInt(cell_size),
                .h = @floatFromInt(cell_size),
            };
            
            _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);
            _ = c.SDL_RenderFillRect(renderer, &rect);
            
            // Draw cell border
            _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 255);
            _ = c.SDL_RenderRect(renderer, &rect);
        }
    }
    
    // Render the entire simulation
    pub fn renderSimulation(
        self: SdlRenderer, 
        map: Map, 
        agents: []const Agent, 
        interactions: []const Interaction
    ) void {
        if (self.renderer == null) return;
        
        // First render the terrain
        for (0..map.height) |y| {
            for (0..map.width) |x| {
                const terrain = map.getTerrainAt(x, y);
                const food = map.getFoodAt(x, y);
                var color = getTerrainColor(terrain);
                if (food > 0) {
                    // Overlay food: yellow highlight
                    color = ColorRGB{ .r = 240, .g = 220, .b = 60 };
                }
                self.renderCell(x, y, color);
            }
        }
        
        // Render interaction lines
        if (self.renderer) |renderer| {
            for (interactions) |interaction| {
                // Find positions of both agents
                const AgentPos = struct { x: usize, y: usize };
                var agent1_pos = AgentPos{ .x = 0, .y = 0 };
                var agent2_pos = AgentPos{ .x = 0, .y = 0 };
                var found1 = false;
                var found2 = false;
                
                for (agents) |agent| {
                    if (agent.id == interaction.agent1_id) {
                        agent1_pos.x = agent.x;
                        agent1_pos.y = agent.y;
                        found1 = true;
                    } else if (agent.id == interaction.agent2_id) {
                        agent2_pos.x = agent.x;
                        agent2_pos.y = agent.y;
                        found2 = true;
                    }
                    
                    if (found1 and found2) break;
                }
                
                if (found1 and found2) {
                    const cell_size = self.config.cell_size;
                    const padding = self.config.window_padding;
                    
                    const half_cell = @divTrunc(cell_size, 2);
                    const x1 = padding + @as(i32, @intCast(agent1_pos.x)) * cell_size + half_cell;
                    const y1 = padding + @as(i32, @intCast(agent1_pos.y)) * cell_size + half_cell;
                    const x2 = padding + @as(i32, @intCast(agent2_pos.x)) * cell_size + half_cell;
                    const y2 = padding + @as(i32, @intCast(agent2_pos.y)) * cell_size + half_cell;
                    
                    // Draw interaction line
                    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 100);
                    _ = c.SDL_RenderLine(renderer, @floatFromInt(x1), @floatFromInt(y1), @floatFromInt(x2), @floatFromInt(y2));
                }
            }
        }
        
        // Then render the agents on top
        for (agents) |agent| {
            if (agent.x < map.width and agent.y < map.height) {
                const color = getAgentColor(agent.type);
                self.renderCell(agent.x, agent.y, color);
            }
        }
    }
    
    // Render simulation status information
    pub fn renderSimulationStatus(
        _: SdlRenderer,
        step_count: usize,
        paused: bool,
        spawn_mode: bool,
        selected_agent_type: AgentType,
        agent_count: usize,
        fps: f32
    ) void {
        _ = step_count;
        _ = paused;
        _ = spawn_mode;
        _ = selected_agent_type;
        _ = agent_count;
        _ = fps;
        
        // This would render status information, but requires SDL_ttf
        // We'll implement this later if needed
    }
};