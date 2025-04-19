#!/bin/bash
# Helper script to run the simulation with multithreading enabled
# Usage: ./run_multi_threaded.sh [thread_count] [additional_args...]
# Example: ./run_multi_threaded.sh 4 --text --iterations 1000

# Default to 4 threads if not specified
THREAD_COUNT=${1:-4}
if [[ "$THREAD_COUNT" =~ ^[0-9]+$ ]]; then
    # If first argument is a number, use it as thread count and shift arguments
    shift
else
    # Otherwise use default thread count
    THREAD_COUNT=4
fi

echo "Running with $THREAD_COUNT threads"
zig build run -- --threads $THREAD_COUNT "$@"