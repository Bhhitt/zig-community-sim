const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const Agent = @import("agent.zig").Agent;
const AgentType = @import("agent.zig").AgentType;
const Interaction = @import("agent.zig").Interaction;
const Map = @import("map.zig").Map;
const Terrain = @import("map.zig").Terrain;

// Configuration constants
pub const CELL_SIZE = 20; // Size of each cell in pixels
pub const WINDOW_PADDING = 20; // Padding around the grid

// Structure to pass input state between main and renderer
pub const AppInput = struct {
    quit: bool = false,
    paused: bool = false,
    step: bool = false,
    toggle_spawn_mode: bool = false,
    spawn_requested: bool = false,
    agent_type_changed: bool = false,
    selected_agent_type: AgentType = .Settler,
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,
    add_benchmark_agents: bool = false,
    add_stress_test_agents: bool = false,
};

pub const SdlRenderer = struct {
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    width: c_int,
    height: c_int,
    initialized: bool,

    pub fn init(map_width: usize, map_height: usize) !SdlRenderer {
        // Calculate window dimensions based on map size and cell size
        const width = @as(c_int, @intCast(map_width * CELL_SIZE + 2 * WINDOW_PADDING));
        const height = @as(c_int, @intCast(map_height * CELL_SIZE + 2 * WINDOW_PADDING));
        
        const init_result = c.SDL_Init(c.SDL_INIT_VIDEO);
        if (!init_result) {
            std.debug.print("Failed to initialize SDL: {s}\n", .{c.SDL_GetError()});
            return error.SDLInitFailed;
        }
        
        const window = c.SDL_CreateWindow(
            "Community Simulation",
            width, height,
            0  // No special flags needed, window will be shown by default
        ) orelse {
            std.debug.print("Failed to create window: {s}\n", .{c.SDL_GetError()});
            return error.SDLCreateWindowFailed;
        };
        
        const renderer = c.SDL_CreateRenderer(
            window,
            null  // Let SDL choose the best renderer
        ) orelse {
            c.SDL_DestroyWindow(window);
            std.debug.print("Failed to create renderer: {s}\n", .{c.SDL_GetError()});
            return error.SDLCreateRendererFailed;
        };
        
        return SdlRenderer{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .initialized = true,
        };
    }
    
    pub fn deinit(self: *SdlRenderer) void {
        if (self.initialized) {
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
    pub fn processEvents(_: *SdlRenderer, spawn_mode: bool, paused: bool) AppInput {
        var app_input = AppInput{
            .quit = false,
            .paused = paused,
            .step = false,
            .toggle_spawn_mode = false,
            .spawn_requested = false,
            .agent_type_changed = false,
            .mouse_x = 0,
            .mouse_y = 0,
            .add_benchmark_agents = false,
            .add_stress_test_agents = false,
        };
        
        var mouse_x: f32 = 0;
        var mouse_y: f32 = 0;
        _ = c.SDL_GetMouseState(&mouse_x, &mouse_y);
        app_input.mouse_x = @intFromFloat(mouse_x);
        app_input.mouse_y = @intFromFloat(mouse_y);
        
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    app_input.quit = true;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_ESCAPE => {
                            app_input.quit = true;
                        },
                        c.SDLK_SPACE => {
                            // Toggle pause state
                            app_input.paused = !app_input.paused;
                        },
                        c.SDLK_RIGHT => {
                            // Step forward if paused
                            if (app_input.paused) {
                                app_input.step = true;
                            }
                        },
                        c.SDLK_A => {
                            // Toggle agent spawn mode
                            app_input.toggle_spawn_mode = true;
                        },
                        c.SDLK_1 => {
                            // Select Settler agent type
                            app_input.selected_agent_type = .Settler;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_2 => {
                            // Select Explorer agent type
                            app_input.selected_agent_type = .Explorer;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_3 => {
                            // Select Builder agent type
                            app_input.selected_agent_type = .Builder;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_4 => {
                            // Select Farmer agent type
                            app_input.selected_agent_type = .Farmer;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_5 => {
                            // Select Miner agent type
                            app_input.selected_agent_type = .Miner;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_6 => {
                            // Select Scout agent type
                            app_input.selected_agent_type = .Scout;
                            app_input.agent_type_changed = true;
                        },
                        c.SDLK_B => {
                            // Benchmark - Add 10 random agents
                            app_input.add_benchmark_agents = true;
                        },
                        c.SDLK_S => {
                            // Stress test - Add 100 random agents
                            app_input.add_stress_test_agents = true;
                        },
                        else => {},
                    }
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        // Only register spawn request if in spawn mode
                        if (spawn_mode) {
                            app_input.spawn_requested = true;
                        }
                    }
                },
                else => {},
            }
        }
        
        return app_input;
    }
    
    // Helper functions to access renderer constants
    pub fn cellSize(_: SdlRenderer) i32 {
        return CELL_SIZE;
    }
    
    pub fn windowPadding(_: SdlRenderer) i32 {
        return WINDOW_PADDING;
    }
    
    // Render the entire simulation
    pub fn renderSimulation(self: SdlRenderer, map: Map, agents: []const Agent, interactions: []const Interaction) void {
        if (self.renderer) |renderer| {
            // Render terrain
            for (0..map.height) |y| {
                for (0..map.width) |x| {
                    const terrain = map.getTerrainAt(x, y);
                    self.renderTerrain(renderer, x, y, terrain);
                }
            }
            
            // Render agents
            for (agents) |agent| {
                self.renderAgent(renderer, agent);
            }
            
            // Show interactions (draw lines between interacting agents)
            for (interactions) |interaction| {
                var agent1: ?Agent = null;
                var agent2: ?Agent = null;
                
                // Find the agents involved in this interaction
                for (agents) |agent| {
                    if (agent.id == interaction.agent1_id) {
                        agent1 = agent;
                    } else if (agent.id == interaction.agent2_id) {
                        agent2 = agent;
                    }
                    
                    if (agent1 != null and agent2 != null) {
                        break;
                    }
                }
                
                if (agent1 != null and agent2 != null) {
                    self.renderInteraction(renderer, agent1.?, agent2.?, interaction);
                }
            }
        }
    }
    
    // Render a single terrain cell
    fn renderTerrain(_: SdlRenderer, renderer: *c.SDL_Renderer, x: usize, y: usize, terrain: Terrain) void {
        const rect = c.SDL_FRect{
            .x = @as(f32, @floatFromInt(x * CELL_SIZE + WINDOW_PADDING)),
            .y = @as(f32, @floatFromInt(y * CELL_SIZE + WINDOW_PADDING)),
            .w = @as(f32, @floatFromInt(CELL_SIZE)),
            .h = @as(f32, @floatFromInt(CELL_SIZE)),
        };
        
        // Set color based on terrain type
        switch (terrain) {
            .Empty => {
                _ = c.SDL_SetRenderDrawColor(renderer, 240, 240, 240, 255); // Light gray
            },
            .Grass => {
                _ = c.SDL_SetRenderDrawColor(renderer, 144, 238, 144, 255); // Light green
            },
            .Forest => {
                _ = c.SDL_SetRenderDrawColor(renderer, 34, 139, 34, 255); // Forest green
            },
            .Mountain => {
                _ = c.SDL_SetRenderDrawColor(renderer, 139, 137, 137, 255); // Gray
            },
            .Water => {
                _ = c.SDL_SetRenderDrawColor(renderer, 65, 105, 225, 255); // Royal blue
            },
        }
        
        _ = c.SDL_RenderFillRect(renderer, &rect);
        
        // Draw cell border
        _ = c.SDL_SetRenderDrawColor(renderer, 200, 200, 200, 255);
        _ = c.SDL_RenderRect(renderer, &rect);
    }
    
    // Render a single agent
    fn renderAgent(_: SdlRenderer, renderer: *c.SDL_Renderer, agent: Agent) void {
        const x = @as(c_int, @intCast(agent.x * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        const y = @as(c_int, @intCast(agent.y * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        const radius = CELL_SIZE / 3;
        
        // Set color based on agent type
        switch (agent.type) {
            .Settler => {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255); // Red
            },
            .Explorer => {
                _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255); // Blue
            },
            .Builder => {
                _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255); // Green
            },
            .Farmer => {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255); // Yellow
            },
            .Miner => {
                _ = c.SDL_SetRenderDrawColor(renderer, 128, 128, 128, 255); // Gray
            },
            .Scout => {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 165, 0, 255); // Orange
            },
        }
        
        // Draw filled circle
        drawCircle(renderer, x, y, radius, true);
        
        // Draw circle outline
        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        drawCircle(renderer, x, y, radius, false);
        
        // Add visual indicator of agent energy (health bar)
        const energyWidth = @as(f32, @floatFromInt(@as(usize, CELL_SIZE - 4) * @as(usize, agent.energy) / 100));
        const energyRect = c.SDL_FRect{
            .x = @as(f32, @floatFromInt(agent.x * CELL_SIZE + WINDOW_PADDING + 2)),
            .y = @as(f32, @floatFromInt(agent.y * CELL_SIZE + WINDOW_PADDING + CELL_SIZE - 4)),
            .w = energyWidth,
            .h = 2,
        };
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255); // Yellow
        _ = c.SDL_RenderFillRect(renderer, &energyRect);
    }
    
    // Render an interaction between two agents
    fn renderInteraction(_: SdlRenderer, renderer: *c.SDL_Renderer, agent1: Agent, agent2: Agent, interaction: Interaction) void {
        const x1 = @as(c_int, @intCast(agent1.x * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        const y1 = @as(c_int, @intCast(agent1.y * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        const x2 = @as(c_int, @intCast(agent2.x * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        const y2 = @as(c_int, @intCast(agent2.y * CELL_SIZE + WINDOW_PADDING + CELL_SIZE / 2));
        
        // Set color based on interaction type
        switch (interaction.type) {
            .Greeting => _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 200),  // Yellow
            .Trading => _ = c.SDL_SetRenderDrawColor(renderer, 255, 165, 0, 200),   // Orange
            .Collaboration => _ = c.SDL_SetRenderDrawColor(renderer, 138, 43, 226, 200),  // Purple
            .Teaching => _ = c.SDL_SetRenderDrawColor(renderer, 30, 144, 255, 200),  // Dodger Blue
            .Resource => _ = c.SDL_SetRenderDrawColor(renderer, 50, 205, 50, 200),   // Lime Green
        }
        
        // Draw line between agents
        _ = c.SDL_RenderLine(renderer, @as(f32, @floatFromInt(x1)), @as(f32, @floatFromInt(y1)), @as(f32, @floatFromInt(x2)), @as(f32, @floatFromInt(y2)));
        
        // Draw a small circle at the midpoint to indicate interaction type
        const mid_x = @divTrunc(x1 + x2, 2);
        const mid_y = @divTrunc(y1 + y2, 2);
        drawCircle(renderer, mid_x, mid_y, @divTrunc(CELL_SIZE, 6), true);
    }
    // Render simulation status information
    pub fn renderSimulationStatus(self: SdlRenderer, _: usize, paused: bool, spawn_mode: bool, selected_agent_type: AgentType, agent_count: usize, fps: f32) void {
        if (self.renderer) |renderer| {
            // Status panel background
            const status_bg = c.SDL_FRect{
                .x = 10,
                .y = 10,
                .w = 180,
                .h = 140, // Increased height for more status info
            };
            
            // Semi-transparent background
            _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 160);
            _ = c.SDL_RenderFillRect(renderer, &status_bg);
            
            // Border
            _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 200);
            _ = c.SDL_RenderRect(renderer, &status_bg);
            
            // Draw status indicators using simple colored rectangles
            
            // Step counter
            const step_rect = c.SDL_FRect{
                .x = 15,
                .y = 15,
                .w = 50,
                .h = 10,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
            _ = c.SDL_RenderFillRect(renderer, &step_rect);
            
            // Agent count
            const count_rect = c.SDL_FRect{
                .x = 15,
                .y = 30,
                .w = @floatFromInt(@as(i32, @intCast(agent_count * 2))),
                .h = 10,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
            _ = c.SDL_RenderFillRect(renderer, &count_rect);
            
            // Paused indicator
            const paused_color = if (paused) 
                [_]u8{ 255, 50, 50, 255 } // Red when paused
            else 
                [_]u8{ 50, 255, 50, 255 }; // Green when running
                
            const paused_rect = c.SDL_FRect{
                .x = 15,
                .y = 45,
                .w = 20,
                .h = 20,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, paused_color[0], paused_color[1], paused_color[2], paused_color[3]);
            _ = c.SDL_RenderFillRect(renderer, &paused_rect);
            
            // Spawn mode indicator
            const spawn_color = if (spawn_mode) 
                [_]u8{ 255, 255, 50, 255 } // Yellow when in spawn mode
            else 
                [_]u8{ 100, 100, 100, 255 }; // Gray when not in spawn mode
                
            const spawn_rect = c.SDL_FRect{
                .x = 45,
                .y = 45,
                .w = 20,
                .h = 20,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, spawn_color[0], spawn_color[1], spawn_color[2], spawn_color[3]);
            _ = c.SDL_RenderFillRect(renderer, &spawn_rect);
            
            // Selected agent type indicator
            var agent_color: [4]u8 = undefined;
            switch (selected_agent_type) {
                .Settler => agent_color = [_]u8{ 255, 0, 0, 255 }, // Red
                .Explorer => agent_color = [_]u8{ 0, 0, 255, 255 }, // Blue
                .Builder => agent_color = [_]u8{ 0, 255, 0, 255 }, // Green
                .Farmer => agent_color = [_]u8{ 255, 255, 0, 255 }, // Yellow
                .Miner => agent_color = [_]u8{ 128, 128, 128, 255 }, // Gray
                .Scout => agent_color = [_]u8{ 255, 165, 0, 255 }, // Orange
            }
            
            const agent_rect = c.SDL_FRect{
                .x = 75,
                .y = 45,
                .w = 20,
                .h = 20,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, agent_color[0], agent_color[1], agent_color[2], agent_color[3]);
            _ = c.SDL_RenderFillRect(renderer, &agent_rect);
            
            // Performance indicator
            const fps_rect = c.SDL_FRect{
                .x = 15,
                .y = 75,
                .w = if (fps > 0) @min(150, @as(f32, @floatFromInt(@as(i32, @intFromFloat(fps * 2.0))))) else 1,
                .h = 10,
            };
            
            // Color based on performance
            if (fps > 40) {
                _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255); // Green for good performance
            } else if (fps > 20) {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255); // Yellow for moderate performance
            } else {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255); // Red for poor performance
            }
            _ = c.SDL_RenderFillRect(renderer, &fps_rect);
            
            // Agent count indicator
            const count_text_rect = c.SDL_FRect{
                .x = 15,
                .y = 95,
                .w = 100,
                .h = 10,
            };
            _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
            _ = c.SDL_RenderFillRect(renderer, &count_text_rect);
            
            // Draw a cursor indicator in spawn mode
            if (spawn_mode) {
                var mouse_x: f32 = 0;
                var mouse_y: f32 = 0;
                _ = c.SDL_GetMouseState(&mouse_x, &mouse_y);
                
                // Calculate grid cell
                const cell_x = @divFloor(@as(i32, @intFromFloat(mouse_x)) - WINDOW_PADDING, CELL_SIZE);
                const cell_y = @divFloor(@as(i32, @intFromFloat(mouse_y)) - WINDOW_PADDING, CELL_SIZE);
                
                // Only show cursor if it's within the grid
                if (cell_x >= 0 and cell_y >= 0) {
                    const highlight_rect = c.SDL_FRect{
                        .x = @floatFromInt(cell_x * CELL_SIZE + WINDOW_PADDING),
                        .y = @floatFromInt(cell_y * CELL_SIZE + WINDOW_PADDING),
                        .w = @floatFromInt(CELL_SIZE),
                        .h = @floatFromInt(CELL_SIZE),
                    };
                    
                    // Semi-transparent highlight
                    _ = c.SDL_SetRenderDrawColor(renderer, agent_color[0], agent_color[1], agent_color[2], 120);
                    _ = c.SDL_RenderFillRect(renderer, &highlight_rect);
                    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 180);
                    _ = c.SDL_RenderRect(renderer, &highlight_rect);
                }
            }
        }
    }
};

// Helper function to draw a circle - now a standalone function
fn drawCircle(renderer: *c.SDL_Renderer, centerX: c_int, centerY: c_int, radius: c_int, filled: bool) void {
    var x: c_int = radius - 1;
    var y: c_int = 0;
    var tx: c_int = 1;
    var ty: c_int = 1;
    var err: c_int = tx - 2 * @as(c_int, @intCast(radius));
    
    while (x >= y) {
        // Each of the following renders an octant of the circle
        if (filled) {
            _ = c.SDL_RenderLine(renderer, 
                @as(f32, @floatFromInt(centerX - x)), @as(f32, @floatFromInt(centerY - y)), 
                @as(f32, @floatFromInt(centerX + x)), @as(f32, @floatFromInt(centerY - y)));
            _ = c.SDL_RenderLine(renderer, 
                @as(f32, @floatFromInt(centerX - x)), @as(f32, @floatFromInt(centerY + y)), 
                @as(f32, @floatFromInt(centerX + x)), @as(f32, @floatFromInt(centerY + y)));
            _ = c.SDL_RenderLine(renderer, 
                @as(f32, @floatFromInt(centerX - y)), @as(f32, @floatFromInt(centerY - x)), 
                @as(f32, @floatFromInt(centerX + y)), @as(f32, @floatFromInt(centerY - x)));
            _ = c.SDL_RenderLine(renderer, 
                @as(f32, @floatFromInt(centerX - y)), @as(f32, @floatFromInt(centerY + x)), 
                @as(f32, @floatFromInt(centerX + y)), @as(f32, @floatFromInt(centerY + x)));
        } else {
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX + x)), @as(f32, @floatFromInt(centerY - y)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX + x)), @as(f32, @floatFromInt(centerY + y)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX - x)), @as(f32, @floatFromInt(centerY - y)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX - x)), @as(f32, @floatFromInt(centerY + y)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX + y)), @as(f32, @floatFromInt(centerY - x)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX + y)), @as(f32, @floatFromInt(centerY + x)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX - y)), @as(f32, @floatFromInt(centerY - x)));
            _ = c.SDL_RenderPoint(renderer, @as(f32, @floatFromInt(centerX - y)), @as(f32, @floatFromInt(centerY + x)));
        }
        
        if (err <= 0) {
            y += 1;
            err += ty;
            ty += 2;
        }
        
        if (err > 0) {
            x -= 1;
            tx += 2;
            err += tx - 2 * @as(c_int, @intCast(radius));
        }
    }
}