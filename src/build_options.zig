// This file contains build options that can be set at build time
// The values here are default fallbacks in case they're not set by the build system

// Whether SDL support is enabled (used for graphics)
// This can be overridden at compile time with -DUSE_SDL=1
pub const USE_SDL = true;

// Other build options can be added here as needed
pub const enable_sdl = USE_SDL; // For compatibility with existing code

// Default map dimensions
pub const DEFAULT_MAP_WIDTH = 60;
pub const DEFAULT_MAP_HEIGHT = 30;