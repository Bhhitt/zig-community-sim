#!/bin/bash
# Helper script to detect SDL3 and run with GUI mode if possible

# Check if SDL3 is installed
if brew list | grep -q sdl3; then
    echo "SDL3 is installed via Homebrew at: /opt/homebrew/opt/sdl3"
    echo
    SDL_PATH="/opt/homebrew/opt/sdl3"
else
    echo "SDL3 not found. Please install it using: brew install sdl3"
    echo "Falling back to text mode..."
    zig build run -- --text
    exit 1
fi

# Create a test C file to check SDL3
cat > /tmp/sdl3_test.c << 'EOF'
#include <SDL3/SDL.h>
#include <stdio.h>

int main() {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        printf("SDL_Init Error: %s\n", SDL_GetError());
        return 1;
    }
    printf("SDL3 initialized successfully!\n");
    SDL_Quit();
    return 0;
}
EOF

# Try to compile and run the test
if cc -o /tmp/sdl3_test /tmp/sdl3_test.c -I$SDL_PATH/include -L$SDL_PATH/lib -lSDL3; then
    if /tmp/sdl3_test; then
        echo "SDL3 works correctly on your system!"
    else
        echo "SDL3 initialization failed. Falling back to text mode."
        zig build run -- --text
        exit 1
    fi
else
    echo "Failed to compile SDL3 test. Falling back to text mode."
    zig build run -- --text
    exit 1
fi

# If we get here, SDL3 is working. Try to build with SDL3
zig build -Dsdl=true -Doptimize=Debug || { echo "Build failed. Exiting."; exit 1; }

# If build succeeded, run with GUI mode
zig build run -- --gui

# Check exit code
if [ $? -ne 0 ]; then
    echo
    echo "GUI mode failed. Falling back to text mode..."
    zig build run -- --text --steps=100
fi

# Clean up
test -f /tmp/sdl3_test.c && rm /tmp/sdl3_test.c
test -f /tmp/sdl3_test && rm /tmp/sdl3_test