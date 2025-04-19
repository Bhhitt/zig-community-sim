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

    pub fn render(self: *StatsWindow, agents: []const Agent, interactions: []const Interaction) void {
        _ = interactions; // Mark as used to fix unused parameter lint
        if (self.renderer == null or self.font == null) return;
        const renderer = self.renderer.?;
        // Throttle updates to once per second
        const now = std.time.milliTimestamp();
        if (now - self.last_render_time < 1000) return;
        self.last_render_time = now;
        _ = c.SDL_SetRenderDrawColor(renderer, 30, 30, 30, 255);
        _ = c.SDL_RenderClear(renderer);

        // Count agent types
        var agent_type_counts: [6]usize = .{0} ** 6;
        for (agents) |agent| {
            agent_type_counts[@intFromEnum(agent.type)] += 1;
        }
        // Render stats as rectangles (placeholder for now)
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
            _ = c.SDL_SetRenderDrawColor(renderer, colors[i][0], colors[i][1], colors[i][2], 255);
            _ = c.SDL_RenderRect(renderer, &c.SDL_FRect{
                .x = @as(f32, 20),
                .y = @floatFromInt(y),
                .w = @as(f32, 30),
                .h = @as(f32, 30),
            });
            // Render agent type count as text
            var buf: [64]u8 = undefined;
            const count_str = std.fmt.bufPrint(&buf, "{d}", .{agent_type_counts[i]}) catch "?";
            const color = c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
            const text_ptr = count_str.ptr;
            const text_len = count_str.len;
            const surface = c.TTF_RenderText_Blended(self.font.?, text_ptr, text_len, color);
            if (surface != null) {
                const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
                if (texture != null) {
                    var dst_rect = c.SDL_FRect{
                        .x = @as(f32, 60),
                        .y = @floatFromInt(y),
                        .w = @floatFromInt(surface.*.w),
                        .h = @floatFromInt(surface.*.h),
                    };
                    _ = c.SDL_RenderTexture(renderer, texture, null, &dst_rect);
                    c.SDL_DestroyTexture(texture);
                }
                c.SDL_DestroySurface(surface);
            }
            y += 40;
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
