#!/bin/bash
# Helper script to run the benchmark with a single thread

echo "Running with single thread configuration"
echo "========================================"

# Build and run with a single thread
zig build run -- --threads 1 "$@"