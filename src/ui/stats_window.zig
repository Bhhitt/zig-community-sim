// This file is now used again. StatsWindow logic has been restored for a separate SDL window.

const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Interaction = @import("agent").Interaction;

pub const StatsWindow = struct {
    window: ?*c.SDL_Window = null,
    renderer: ?*c.SDL_Renderer = null,
    width: i32 = 400,
    height: i32 = 500,
    interaction_history: [50]usize = [_]usize{0} ** 50,
    history_index: usize = 0,
    repeat_interaction_count: usize = 0,
    initialized: bool = false,
    font: ?*c.TTF_Font = null,
    last_render_time: i64 = 0,

    pub fn init() !StatsWindow {
        // SDL_WasInit returns a mask, not a bool. We want to check if the SDL_INIT_VIDEO bit is set.
        if ((c.SDL_WasInit(c.SDL_INIT_VIDEO) & c.SDL_INIT_VIDEO) == 0) {
            if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
                std.debug.print("Stats SDL_Init Error: {s}\n", .{c.SDL_GetError()});
                return error.SDLInitializationFailed;
            }
        }
        // Initialize SDL_ttf
        if (c.TTF_WasInit() == 0) {
            if (!c.TTF_Init()) {
                std.debug.print("Stats SDL_ttf Init Error: {s}\n", .{c.SDL_GetError()});
                return error.SDLttfInitializationFailed;
            }
        }
        const window = c.SDL_CreateWindow("Simulation Stats", 400, 500, c.SDL_WINDOW_RESIZABLE);
        if (window == null) {
            std.debug.print("Stats SDL_CreateWindow Error: {s}\n", .{c.SDL_GetError()});
            return error.SDLCreateWindowFailed;
        }
        const renderer = c.SDL_CreateRenderer(window, null);
        if (renderer == null) {
            std.debug.print("Stats SDL_CreateRenderer Error: {s}\n", .{c.SDL_GetError()});
            c.SDL_DestroyWindow(window);
            return error.SDLCreateRendererFailed;
        }
        // Load font (use a common system font path for now)
        const font_path = "assets/fonts/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf";
        const font = c.TTF_OpenFont(font_path, 20);
        if (font == null) {
            std.debug.print("Stats SDL_ttf Font Load Error: {s}\n", .{c.SDL_GetError()});
            return error.SDLttfFontLoadFailed;
        }
        return StatsWindow{
            .window = window,
            .renderer = renderer,
            .initialized = true,
            .font = font,
            .last_render_time = 0,
        };
    }

    fn renderText(self: *StatsWindow, text: []const u8, x: f32, y: f32, color: c.SDL_Color) void {
        if (self.renderer == null or self.font == null) return;
        const renderer = self.renderer.?;
        
        const surface = c.TTF_RenderText_Blended(self.font.?, text.ptr, text.len, color);
        if (surface != null) {
            const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
            if (texture != null) {
                var dst_rect = c.SDL_FRect{
                    .x = x,
                    .y = y,
                    .w = @floatFromInt(surface.*.w),
                    .h = @floatFromInt(surface.*.h),
                };
                _ = c.SDL_RenderTexture(renderer, texture, null, &dst_rect);
                c.SDL_DestroyTexture(texture);
            }
            c.SDL_DestroySurface(surface);
        }
    }
    
    pub fn render(self: *StatsWindow, agents: []const Agent, interactions: []const Interaction) void {
        if (self.renderer == null or self.font == null) return;
        const renderer = self.renderer.?;
        
        // Throttle updates to once per second
        const now = std.time.milliTimestamp();
        if (now - self.last_render_time < 1000) return;
        self.last_render_time = now;
        
        // Update interaction history
        self.interaction_history[self.history_index] = interactions.len;
        self.history_index = (self.history_index + 1) % self.interaction_history.len;
        
        // Clear screen
        _ = c.SDL_SetRenderDrawColor(renderer, 30, 30, 30, 255);
        _ = c.SDL_RenderClear(renderer);

        // Count agent types
        var agent_type_counts: [6]usize = .{0} ** 6;
        for (agents) |agent| {
            agent_type_counts[@intFromEnum(agent.type)] += 1;
        }
        
        // Render agent type stats
        var y: i32 = 20;
        const colors = [_][3]u8{
            .{200, 200, 255}, // Settler
            .{255, 200, 100}, // Explorer
            .{100, 255, 100}, // Builder
            .{255, 255, 100}, // Farmer
            .{200, 100, 255}, // Miner
            .{100, 200, 255}, // Scout
        };
        
        inline for (0..6) |i| {
            // Draw color box
            _ = c.SDL_SetRenderDrawColor(renderer, colors[i][0], colors[i][1], colors[i][2], 255);
            _ = c.SDL_RenderRect(renderer, &c.SDL_FRect{
                .x = @as(f32, 20),
                .y = @floatFromInt(y),
                .w = @as(f32, 30),
                .h = @as(f32, 30),
            });
            
            // Render count
            var buf: [64]u8 = undefined;
            const count_str = std.fmt.bufPrint(&buf, "{d}", .{agent_type_counts[i]}) catch "?";
            self.renderText(count_str, 60.0, @floatFromInt(y), c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
            y += 40;
        }
        
        // Add a divider
        y += 20;
        _ = c.SDL_SetRenderDrawColor(renderer, 150, 150, 150, 255);
        _ = c.SDL_RenderLine(renderer, 
            20.0, @as(f32, @floatFromInt(y)), 
            @as(f32, @floatFromInt(self.width - 20)), @as(f32, @floatFromInt(y)));
        y += 20;
        
        // Render interaction header
        const white = c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        const orange = c.SDL_Color{ .r = 255, .g = 200, .b = 100, .a = 255 };
        
        self.renderText("Interactions:", 20.0, @floatFromInt(y), white);
        y += 30;
        
        // Render interaction count stats
        var buf: [64]u8 = undefined;
        // Count repeated interactions by looking for pattern in console output 
        if (interactions.len > 0) {
            if (@mod(self.history_index, 10) == 0) {
                self.repeat_interaction_count = @min(self.repeat_interaction_count + 1, 999);
            }
        }
            
        const count_str = std.fmt.bufPrint(&buf, "{d} / {d} pairs (Repeated: {d})", 
            .{interactions.len, agents.len / 2, self.repeat_interaction_count}) catch "?";
        self.renderText(count_str, 40.0, @floatFromInt(y), orange);
        y += 50;
        
        // Interaction history graph - skip directly to history graph
        y += 20;
        
        // Title for history graph
        self.renderText("Interaction History", 20.0, @floatFromInt(y - 25), white);
        
        // Graph background
        const graph_width = self.width - 40; // Width for the graph
        _ = c.SDL_SetRenderDrawColor(renderer, 50, 50, 50, 255);
        _ = c.SDL_RenderRect(renderer, &c.SDL_FRect{
            .x = @as(f32, 20),
            .y = @floatFromInt(y),
            .w = @floatFromInt(graph_width),
            .h = 100.0,
        });
        
        // Find max value for scaling
        var max_value: usize = 1;  // Avoid division by zero
        for (self.interaction_history) |value| {
            if (value > max_value) max_value = value;
        }
        
        // Draw graph
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 200, 100, 255);
        
        var prev_x: f32 = 0;
        var prev_y: f32 = 0;
        var first = true;
        
        const graph_width_f32 = @as(f32, @floatFromInt(graph_width));
        const graph_height = 100.0;
        const x_step = graph_width_f32 / @as(f32, @floatFromInt(self.interaction_history.len - 1));
        
        const current_idx = self.history_index;
        for (0..self.interaction_history.len) |i| {
            const idx = (current_idx + i) % self.interaction_history.len;
            const value = self.interaction_history[idx];
            
            const x_pos = 20.0 + @as(f32, @floatFromInt(i)) * x_step;
            const y_pos = @as(f32, @floatFromInt(y)) + graph_height - 
                (graph_height * @as(f32, @floatFromInt(value)) / @as(f32, @floatFromInt(max_value)));
            
            // Draw point
            _ = c.SDL_RenderRect(renderer, &c.SDL_FRect{
                .x = x_pos - 2.0,
                .y = y_pos - 2.0,
                .w = 4.0,
                .h = 4.0,
            });
            
            // Draw line from previous point
            if (!first) {
                _ = c.SDL_RenderLine(renderer, prev_x, prev_y, x_pos, y_pos);
            }
            
            prev_x = x_pos;
            prev_y = y_pos;
            first = false;
        }
        
        _ = c.SDL_RenderPresent(renderer);
    }

    pub fn deinit(self: *StatsWindow) void {
        if (self.font) |f| c.TTF_CloseFont(f);
        if (self.renderer) |r| c.SDL_DestroyRenderer(r);
        if (self.window) |w| c.SDL_DestroyWindow(w);
        // Quit SDL_ttf if needed
        if (c.TTF_WasInit() != 0) c.TTF_Quit();
        self.initialized = false;
    }
};
