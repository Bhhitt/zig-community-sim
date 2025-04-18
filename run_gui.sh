#!/bin/bash
# Simple script to build and run the GUI simulation

if brew list | grep -q sdl3; then
    echo "SDL3 is installed via Homebrew."
else
    echo "SDL3 not found. Please install it using: brew install sdl3"
    exit 1
fi

echo "Building with SDL3 GUI support..."
zig build -Dsdl=true -Doptimize=Debug || { echo "Build failed. Exiting."; exit 1; }

echo "Running simulation with GUI..."
zig build run -- --gui