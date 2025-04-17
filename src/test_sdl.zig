const std = @import("std");

// Import the C library for SDL
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn main() !void {
    std.debug.print("Testing SDL3 initialization...\n", .{});
    
    // Initialize SDL
    const result = c.SDL_Init(c.SDL_INIT_VIDEO);
    if (result != 0) {
        std.debug.print("SDL_Init Error: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    
    std.debug.print("SDL3 initialized successfully!\n", .{});
    
    // Create a window
    const window = c.SDL_CreateWindow(
        "SDL3 Test Window",
        640,
        480,
        c.SDL_WINDOW_SHOWN
    );
    
    if (window == null) {
        std.debug.print("SDL_CreateWindow Error: {s}\n", .{c.SDL_GetError()});
        return error.SDLCreateWindowFailed;
    }
    defer c.SDL_DestroyWindow(window);
    
    std.debug.print("SDL3 window created successfully!\n", .{});
    
    // Create renderer
    const renderer = c.SDL_CreateRenderer(window, null, c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer Error: {s}\n", .{c.SDL_GetError()});
        return error.SDLCreateRendererFailed;
    }
    defer c.SDL_DestroyRenderer(renderer);
    
    std.debug.print("SDL3 renderer created successfully!\n", .{});
    
    // Clear screen with a color
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderClear(renderer);
    c.SDL_RenderPresent(renderer);
    
    // Wait for 2 seconds
    std.time.sleep(2 * std.time.ns_per_s);
    
    std.debug.print("SDL3 test completed successfully!\n", .{});
}