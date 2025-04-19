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
    // Viewport origin (top-left cell in map coordinates)
    view_x: usize = 0,
    view_y: usize = 0,

    pub fn init(map_width: usize, map_height: usize) !SdlRenderer {
        // Use a sensible default window size
        const screen_width: i32 = 1200;
        const screen_height: i32 = 800;
        const config = RenderConfig.initForScreen(map_width, map_height, screen_width, screen_height);

        // Calculate window dimensions based on map size and cell size
        var width: i32 = @intCast(map_width);
        var height: i32 = @intCast(map_height);
        width = width * config.cell_size + 2 * config.window_padding;
        height = height * config.cell_size + 2 * config.window_padding;
        if (width > screen_width) width = screen_width;
        if (height > screen_height) height = screen_height;

        // Initialize SDL
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            std.debug.print("SDL_Init Error: {s}\n", .{c.SDL_GetError()});
            return error.SDLInitializationFailed;
        }
        std.debug.print("SDL3 initialized successfully!\n", .{});

        // Create window
        // Use SDL_WINDOW_RESIZABLE flag to make window adjustable
        const window = c.SDL_CreateWindow("Zig Community Simulation", width, height, c.SDL_WINDOW_RESIZABLE);

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
            .view_x = 0,
            .view_y = 0,
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
    pub fn processEvents(self: *SdlRenderer, spawn_mode: bool, current_paused: bool, map_width: usize, map_height: usize) AppInput {
        var result = AppInput{
            .paused = current_paused,
        };

        var event: c.SDL_Event = undefined;
        // Calculate visible cells for clamping
        const w = @as(isize, self.width) - @as(isize, 2 * self.config.window_padding);
        const h = @as(isize, self.height) - @as(isize, 2 * self.config.window_padding);
        const cells_x: usize = @intCast(@divTrunc(w, @as(isize, self.config.cell_size)));
        const cells_y: usize = @intCast(@divTrunc(h, @as(isize, self.config.cell_size)));
        const max_view_x = if (map_width > cells_x) map_width - cells_x else 0;
        const max_view_y = if (map_height > cells_y) map_height - cells_y else 0;
        std.debug.print("[DEBUG] map_width: {} map_height: {} cells_x: {} cells_y: {} max_view_x: {} max_view_y: {}\n", .{ map_width, map_height, cells_x, cells_y, max_view_x, max_view_y });
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    result.quit = true;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    const scancode = event.key.scancode;
                    if (scancode == c.SDL_SCANCODE_ESCAPE) {
                        result.quit = true;
                    } else if (scancode == c.SDL_SCANCODE_SPACE) {
                        result.paused = !current_paused;
                    } else if (scancode == c.SDL_SCANCODE_RIGHT and current_paused) {
                        result.step = true;
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
                    } else if (scancode == c.SDL_SCANCODE_LEFT) {
                        if (self.view_x > 0) self.view_x -= 1;
                        std.debug.print("view_x: {}\n", .{self.view_x});
                    } else if (scancode == c.SDL_SCANCODE_RIGHT) {
                        self.view_x += 1;
                        std.debug.print("view_x: {}\n", .{self.view_x});
                    } else if (scancode == c.SDL_SCANCODE_UP) {
                        if (self.view_y > 0) self.view_y -= 1;
                        std.debug.print("view_y: {}\n", .{self.view_y});
                    } else if (scancode == c.SDL_SCANCODE_DOWN) {
                        self.view_y += 1;
                        std.debug.print("view_y: {}\n", .{self.view_y});
                    }
                    // Clamp viewport after any arrow key
                    if (scancode == c.SDL_SCANCODE_LEFT or scancode == c.SDL_SCANCODE_RIGHT or scancode == c.SDL_SCANCODE_UP or scancode == c.SDL_SCANCODE_DOWN) {
                        if (self.view_x > max_view_x) self.view_x = max_view_x;
                        if (self.view_y > max_view_y) self.view_y = max_view_y;
                        if (self.view_x < 0) self.view_x = 0;
                        if (self.view_y < 0) self.view_y = 0;
                        std.debug.print("[CLAMP] view_x: {} view_y: {}\n", .{ self.view_x, self.view_y });
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
            .Dirt => .{ .r = 139, .g = 69, .b = 19 }, // brown for dirt
            .Grass => .{ .r = 100, .g = 200, .b = 100 },
            .Forest => .{ .r = 34, .g = 139, .b = 34 },
            .Mountain => .{ .r = 160, .g = 160, .b = 160 },
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
    fn renderCell(self: SdlRenderer, x: usize, y: usize, color: ColorRGB) void {
        if (self.renderer) |renderer| {
            const cell_size = self.config.cell_size;
            const padding = self.config.window_padding;

            // Convert x, y from usize to i32 for pixel math
            const xi: i32 = @intCast(x);
            const yi: i32 = @intCast(y);

            const rect = c.SDL_FRect{
                .x = @as(f32, @floatFromInt(padding + xi * cell_size)),
                .y = @as(f32, @floatFromInt(padding + yi * cell_size)),
                .w = @as(f32, @floatFromInt(cell_size)),
                .h = @as(f32, @floatFromInt(cell_size)),
            };

            _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);
            _ = c.SDL_RenderFillRect(renderer, &rect);

            // Draw cell border
            _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 255);
            _ = c.SDL_RenderRect(renderer, &rect);
        }
    }

    // Render the entire simulation
    pub fn renderSimulation(self: *SdlRenderer, map: Map, agents: []const Agent, interactions: []const Interaction) void {
        if (self.renderer == null) return;

        // Render only the visible terrain (viewport)
        const w = @as(isize, self.width) - @as(isize, 2 * self.config.window_padding);
        const h = @as(isize, self.height) - @as(isize, 2 * self.config.window_padding);
        const cells_x: usize = @intCast(@divTrunc(w, @as(isize, self.config.cell_size)));
        const cells_y: usize = @intCast(@divTrunc(h, @as(isize, self.config.cell_size)));
        const max_view_x = if (map.width > cells_x) map.width - cells_x else 0;
        const max_view_y = if (map.height > cells_y) map.height - cells_y else 0;
        var view_x = self.view_x;
        var view_y = self.view_y;
        if (view_x > max_view_x) view_x = max_view_x;
        if (view_y > max_view_y) view_y = max_view_y;
        for (0..cells_y) |yy| {
            const y = view_y + yy;
            if (y >= map.height) break;
            for (0..cells_x) |xx| {
                const x = view_x + xx;
                if (x >= map.width) break;
                const terrain = map.getTerrainAt(x, y);
                const food = map.getFoodAt(x, y);
                var color = getTerrainColor(terrain);
                if (food > 0) {
                    color = ColorRGB{ .r = 240, .g = 220, .b = 60 };
                }
                self.renderCell(xx, yy, color);
            }
        }

        // Render interaction lines
        if (self.renderer) |renderer| {
            for (interactions) |interaction| {
                // Find positions of both agents
                const AgentPos = struct { x: i32, y: i32 };
                var agent1_pos = AgentPos{ .x = 0, .y = 0 };
                var agent2_pos = AgentPos{ .x = 0, .y = 0 };
                var found1 = false;
                var found2 = false;

                for (agents) |agent| {
                    if (agent.id == interaction.agent1_id) {
                        agent1_pos.x = @intFromFloat(agent.x);
                        agent1_pos.y = @intFromFloat(agent.y);
                        found1 = true;
                    } else if (agent.id == interaction.agent2_id) {
                        agent2_pos.x = @intFromFloat(agent.x);
                        agent2_pos.y = @intFromFloat(agent.y);
                        found2 = true;
                    }

                    if (found1 and found2) break;
                }

                if (found1 and found2) {
                    const cell_size = self.config.cell_size;
                    const padding = self.config.window_padding;

                    const half_cell = @divTrunc(cell_size, 2);
                    const x1: i32 = padding + agent1_pos.x * cell_size + half_cell;
                    const y1: i32 = padding + agent1_pos.y * cell_size + half_cell;
                    const x2: i32 = padding + agent2_pos.x * cell_size + half_cell;
                    const y2: i32 = padding + agent2_pos.y * cell_size + half_cell;

                    // Draw interaction line
                    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 100);
                    _ = c.SDL_RenderLine(renderer, @as(f32, @floatFromInt(x1)), @as(f32, @floatFromInt(y1)), @as(f32, @floatFromInt(x2)), @as(f32, @floatFromInt(y2)));
                }
            }
        }

        // Then render the agents on top
        if (self.renderer) |renderer| {
            // Compute visible cell range ONCE for the viewport
            const vw = @as(isize, self.width) - @as(isize, 2 * self.config.window_padding);
            const vh = @as(isize, self.height) - @as(isize, 2 * self.config.window_padding);
            const viewport_cells_x: usize = @intCast(@divTrunc(vw, @as(isize, self.config.cell_size)));
            const viewport_cells_y: usize = @intCast(@divTrunc(vh, @as(isize, self.config.cell_size)));
            std.debug.assert(map.width <= std.math.maxInt(i32));
            std.debug.assert(map.height <= std.math.maxInt(i32));
            const map_width_i32: i32 = @intCast(map.width);
            const map_height_i32: i32 = @intCast(map.height);
            const viewport_cells_x_i32: i32 = @intCast(viewport_cells_x);
            const viewport_cells_y_i32: i32 = @intCast(viewport_cells_y);
            const view_x_i32: i32 = @intCast(view_x);
            const view_y_i32: i32 = @intCast(view_y);
            for (agents) |agent| {
                // Only render if agent is within the visible viewport AND inside the map bounds
                const ax: i32 = @intFromFloat(agent.x);
                const ay: i32 = @intFromFloat(agent.y);
                if (ax >= view_x_i32 and ay >= view_y_i32 and ax < view_x_i32 + viewport_cells_x_i32 and ay < view_y_i32 + viewport_cells_y_i32 and ax >= 0 and ay >= 0 and ax < map_width_i32 and ay < map_height_i32) {
                    const color = getAgentColor(agent.type);
                    const cell_size = self.config.cell_size;
                    const padding = self.config.window_padding;
                    // Map agent's map-relative position to screen position
                    const px = padding + (ax - view_x_i32) * cell_size;
                    const py = padding + (ay - view_y_i32) * cell_size;
                    // Only draw if inside drawable area (not in margin)
                    if (px >= padding and py >= padding and px < self.width - padding and py < self.height - padding) {
                        var rect: c.SDL_FRect = .{
                            .x = @as(f32, @floatFromInt(px)) + 1.0,
                            .y = @as(f32, @floatFromInt(py)) + 1.0,
                            .w = @as(f32, @floatFromInt(cell_size)) - 2.0,
                            .h = @as(f32, @floatFromInt(cell_size)) - 2.0,
                        };
                        _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);
                        _ = c.SDL_RenderFillRect(renderer, &rect);
                        std.debug.print("[AGENT] id={} map=({}, {}) view=({}, {}) px={}, py={}\n", .{agent.id, ax, ay, view_x_i32, view_y_i32, px, py});
                    }
                }
            }
        }
    }

    // Render simulation status information
    pub fn renderSimulationStatus(_: SdlRenderer, step_count: usize, paused: bool, spawn_mode: bool, selected_agent_type: AgentType, agent_count: usize, fps: f32) void {
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
